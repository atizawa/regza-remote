#if !REGZA_FAKES_DISABLED
import Foundation
import RegzaDomain
import RegzaInfrastructure

/// アプリの中から偽物につなぐ通信。本物の Repository に渡すので、返事の読み取りからアプリと同じ処理を通る。
/// 偽物のいないアドレスには、本物と同じくつながらない (外への通信は起きない)
public struct FakeServersTransport: HTTPTransport {
    public let servers: FakeServers
    private let scenario: FakeScenario

    public init(scenario: FakeScenario = .standard) {
        self.scenario = scenario
        servers = FakeServers(scenario: scenario)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let host = request.url.host ?? ""
        if scenario.unreachable.contains(host) {
            throw RegzaError.connection(.cannotConnect)
        }
        if let response = scenario.responses[request.url.path] {
            return HTTPResponse(statusCode: response.status, headers: [:], body: Data(response.body.json.utf8))
        }
        guard let response = servers.respond(to: FakeRequest(request)) else {
            throw RegzaError.connection(.cannotConnect)
        }
        return response
    }
}
#endif
