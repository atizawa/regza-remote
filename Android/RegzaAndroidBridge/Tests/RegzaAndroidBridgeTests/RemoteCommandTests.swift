import Foundation
import RegzaApp
import Testing

@testable import RegzaAndroidBridge

@MainActor
@Suite struct RemoteCommandTests {
    @Test func sendsOnlyTheRequestedKeyAndDoesNotCleanUpStreams() async {
        let transport = CommandTransport(status: 200, body: "0")
        let factory = RegzaAndroidAppFactory(httpTransport: transport)
        let storage = MemoryStorage(["host": "192.0.2.1", "user": "widget-user", "streamHost": "192.0.2.2", "ownStreamIDs": "42"])
        let error = await factory.sendRemoteKey(.volumeUp, storage: storage)
        #expect(error == nil)
        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.url.path == "/remote/remote.htm")
        #expect(transport.requests.first?.url.query?.contains("key=") == true)
        #expect(storage.values["ownStreamIDs"] == "42")
    }

    @Test func missingConnectionDoesNotSendAnyRequest() async {
        let transport = CommandTransport(status: 200, body: "0")
        let error = await RegzaAndroidAppFactory(httpTransport: transport).sendRemoteKey(.power, storage: MemoryStorage([:]))
        #expect(error == RegzaError.app(.notConfigured).localizedDescription)
        #expect(transport.requests.isEmpty)
    }

    @Test func commandRejectionIsReturnedAfterSending() async {
        let transport = CommandTransport(status: 200, body: "1")
        let error = await RegzaAndroidAppFactory(httpTransport: transport).sendRemoteKey(
            .mute, storage: MemoryStorage(["host": "192.0.2.1"]))
        #expect(error == RegzaError.app(.commandRejected("1")).localizedDescription)
    }
}

private final class CommandTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [HTTPRequest] = []
    let status: Int
    let body: String

    init(status: Int, body: String) {
        self.status = status
        self.body = body
    }

    var requests: [HTTPRequest] { lock.withLock { recorded } }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recorded.append(request) }
        return HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }
}
