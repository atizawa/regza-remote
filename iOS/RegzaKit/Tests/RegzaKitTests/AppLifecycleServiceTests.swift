import Foundation
import RegzaInfrastructure
import Testing

@testable import AppServices

@MainActor
@Suite struct AppLifecycleServiceTests {
    @Test(arguments: [("", [1]), ("192.0.2.20", [])])
    func skipsCleanupWithoutServerOrStreams(host: String, streamIDs: [Int]) async {
        let preferencesManager = makePreferencesManager(host: host, streamIDs: streamIDs)
        let httpTransport = ResponseTransport()
        let appLifecycleService = AppLifecycleService(preferencesManager: preferencesManager, httpTransport: httpTransport)

        #expect(appLifecycleService.applicationWillTerminate() == .success)
        #expect(await httpTransport.requests.isEmpty)
        #expect(preferencesManager.integers(forKey: .ownStreamIDs) == streamIDs)
    }

    @Test func removesStoppedAndMissingStreamsButKeepsFailures() async {
        let preferencesManager = makePreferencesManager(host: "192.0.2.20", streamIDs: [1, 2, 3, 4, 5])
        let httpTransport = ResponseTransport(statusCodes: [2: 404, 3: 500], failedIDs: [4])
        let appLifecycleService = AppLifecycleService(preferencesManager: preferencesManager, httpTransport: httpTransport)

        #expect(appLifecycleService.applicationWillTerminate() == .success)
        #expect(await httpTransport.requests == (1...5).map { "DELETE 192.0.2.20/api/streams/\($0)" })
        #expect(preferencesManager.integers(forKey: .ownStreamIDs) == [3, 4])
    }

    @Test func usesServerSettingsAtTermination() async {
        let preferencesManager = makePreferencesManager(host: "192.0.2.20", streamIDs: [7])
        let httpTransport = ResponseTransport()
        let appLifecycleService = AppLifecycleService(preferencesManager: preferencesManager, httpTransport: httpTransport)
        preferencesManager.setValue("192.0.2.30", forKey: .streamHost)

        #expect(appLifecycleService.applicationWillTerminate() == .success)
        #expect(await httpTransport.requests == ["DELETE 192.0.2.30/api/streams/7"])
        #expect(preferencesManager.integers(forKey: .ownStreamIDs).isEmpty)
    }

    @Test func timeoutKeepsIDsUntilStopCompletes() async throws {
        let preferencesManager = makePreferencesManager(host: "192.0.2.20", streamIDs: [7])
        let httpTransport = SuspendedTransport()
        let appLifecycleService = AppLifecycleService(
            preferencesManager: preferencesManager, httpTransport: httpTransport, maximumWait: .milliseconds(20))

        #expect(appLifecycleService.applicationWillTerminate() == .timedOut)
        #expect(preferencesManager.integers(forKey: .ownStreamIDs) == [7])

        // プロセスがまだ動いていれば、待機上限を過ぎても停止できた時点で ID を消す。
        await httpTransport.allowResponse()
        for _ in 0..<100 {
            if preferencesManager.integers(forKey: .ownStreamIDs).isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(preferencesManager.integers(forKey: .ownStreamIDs).isEmpty)
    }

    private func makePreferencesManager(host: String, streamIDs: [Int]) -> PreferencesManager {
        let preferencesManager = PreferencesManager(storage: MemoryPreferencesStorage(values: [.streamHost: host]))
        preferencesManager.setIntegers(streamIDs, forKey: .ownStreamIDs)
        return preferencesManager
    }
}

private actor ResponseTransport: HTTPTransport {
    let statusCodes: [Int: Int]
    let failedIDs: Set<Int>
    private(set) var requests: [String] = []

    init(statusCodes: [Int: Int] = [:], failedIDs: Set<Int> = []) {
        self.statusCodes = statusCodes
        self.failedIDs = failedIDs
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append("\(request.method) \(request.url.host ?? "")\(request.url.path)")
        let id = Int(request.url.lastPathComponent) ?? -1
        if failedIDs.contains(id) { throw URLError(.cannotConnectToHost) }
        return HTTPResponse(statusCode: statusCodes[id] ?? 200, headers: [:], body: Data())
    }
}

private actor SuspendedTransport: HTTPTransport {
    private var canRespond = false
    private var continuation: CheckedContinuation<Void, Never>?

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if !canRespond {
            await withCheckedContinuation { continuation = $0 }
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: Data())
    }

    func allowResponse() {
        canRespond = true
        continuation?.resume()
        continuation = nil
    }
}
