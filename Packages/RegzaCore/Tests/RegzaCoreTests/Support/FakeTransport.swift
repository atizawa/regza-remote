import Foundation

@testable import RegzaDomain
@testable import RegzaInfrastructure

/// 決めた返事を返し、届いた問い合わせを覚えておく
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let respond: @Sendable (HTTPRequest) -> HTTPResponse
    private let lock = NSLock()
    private var requests: [HTTPRequest] = []

    init(_ respond: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.respond = respond
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests.map(\.url.path)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { requests.append(request) }
        return respond(request)
    }
}
