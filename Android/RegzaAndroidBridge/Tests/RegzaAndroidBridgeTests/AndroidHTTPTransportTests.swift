import Foundation
import RegzaApp
import Testing

@testable import RegzaAndroidBridge

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AndroidHTTPTransportTests {
    @Test func forwardsRequestAndBinaryResponse() async throws {
        let bytes: [UInt8] = [0, 128, 255]
        let client = RecordingHTTPClient { request, completion in
            #expect(request.method == "POST")
            #expect(request.address == "http://127.0.0.1/api?a=1")
            #expect(request.headers == ["Content-Type", "application/octet-stream", "X-Test", "value"])
            #expect(request.body == [0, -128, -1])
            #expect(request.hasBody)
            #expect(request.timeout == 0.5)
            completion.succeed(201, ["X-Result", "ok"], [0, -128, -1])
            completion.fail("遅れて届いた失敗")
        }
        let response = try await AndroidHTTPTransport(httpClient: client).send(
            HTTPRequest(
                method: "POST", url: try #require(URL(string: "http://127.0.0.1/api?a=1")),
                headers: ["Content-Type": "application/octet-stream", "X-Test": "value"], body: Data(bytes), timeout: 0.5))
        #expect(response.statusCode == 201)
        #expect(response.value(forHTTPHeaderField: "x-result") == "ok")
        #expect(response.body == Data(bytes))
    }

    @Test func propagatesFailure() async throws {
        let client = RecordingHTTPClient { _, completion in completion.fail("読み取りに失敗しました") }
        await #expect(throws: RegzaError.network("読み取りに失敗しました")) {
            try await AndroidHTTPTransport(httpClient: client).send(request())
        }
    }

    @Test func rejectsMalformedResponse() async throws {
        let client = RecordingHTTPClient { _, completion in completion.succeed(200, ["missing-value"], []) }
        await #expect(throws: RegzaError.network("不正なレスポンスです")) {
            try await AndroidHTTPTransport(httpClient: client).send(request())
        }
    }

    @Test func cancellationStopsPlatformCallAndIgnoresLateResponse() async throws {
        let client = RecordingHTTPClient()
        let transport = AndroidHTTPTransport(httpClient: client)
        let task = Task { try await transport.send(request()) }
        try await wait { !client.requests.isEmpty }
        let outgoing = try #require(client.requests.first)
        task.cancel()
        await #expect(throws: RegzaError.network("通信を取り消しました")) { try await task.value }
        try await wait { client.cancelled == [outgoing.id] }
        client.completion?.succeed(200, [], [])
    }

    @Test func cancellationBeforeStartDoesNotLaunchRequest() async throws {
        let client = RecordingHTTPClient()
        let transport = AndroidHTTPTransport(httpClient: client)
        let task = Task { try await transport.send(request()) }
        task.cancel()
        await #expect(throws: RegzaError.network("通信を取り消しました")) { try await task.value }
        try await wait { !client.cancelled.isEmpty }
        #expect(client.requests.isEmpty)
    }

    @Test(arguments: [("https://127.0.0.1:4430/", false), ("https://127.0.0.1:443/", true), ("http://127.0.0.1:4430/", true)])
    func certificateExceptionIsLimitedToTelevisionHTTPS(address: String, verifies: Bool) throws {
        let request = RegzaAndroidHTTPRequest(HTTPRequest(url: try #require(URL(string: address)), timeout: 3))
        #expect(request.verifiesCertificate == verifies)
    }

    private func request() throws -> HTTPRequest {
        HTTPRequest(url: try #require(URL(string: "http://127.0.0.1/")), timeout: 3)
    }

    private func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
        #expect(condition())
    }
}

private final class RecordingHTTPClient: RegzaAndroidHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var outgoing: [RegzaAndroidHTTPRequest] = []
    private var cancellations: [String] = []
    private var pending: RegzaAndroidHTTPCompletion?
    private let respond: (RegzaAndroidHTTPRequest, RegzaAndroidHTTPCompletion) -> Void

    init(_ respond: @escaping (RegzaAndroidHTTPRequest, RegzaAndroidHTTPCompletion) -> Void = { _, _ in }) {
        self.respond = respond
    }

    var requests: [RegzaAndroidHTTPRequest] { lock.withLock { outgoing } }
    var cancelled: [String] { lock.withLock { cancellations } }
    var completion: RegzaAndroidHTTPCompletion? { lock.withLock { pending } }

    func start(_ request: RegzaAndroidHTTPRequest, completion: RegzaAndroidHTTPCompletion) {
        lock.withLock {
            outgoing.append(request)
            pending = completion
        }
        respond(request, completion)
    }

    func cancel(_ id: String) {
        lock.withLock { cancellations.append(id) }
    }
}
