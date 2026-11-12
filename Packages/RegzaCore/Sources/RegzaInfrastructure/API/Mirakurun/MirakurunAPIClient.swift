import Foundation
import MirakurunAPI
import RegzaDomain

/// 録画サーバー Mirakurun から番組表を読む。認証は不要。
///
/// テレビの v2 API は番組名を返さないので、放送中の番組名と番組表はこちらから取る。
/// テレビと Mirakurun は同じ放送波の ID (network_id / service_id / event_id) を使っているので、変換して照らし合わせられる。
public final class MirakurunAPIClient: Sendable {
    public static let defaultPort = ServerPort.mirakurun

    /// `192.168.0.2` か `192.168.0.2:40772`
    public let host: String
    private let timeout: TimeInterval
    private let transport: any HTTPTransport

    public init(host: String, timeout: TimeInterval = 10, transport: any HTTPTransport) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
        self.transport = transport
    }

    /// 注入された通信方式とタイムアウトを保ったまま接続先を差し替える。
    public func replacingHost(_ host: String) -> MirakurunAPIClient {
        MirakurunAPIClient(host: host, timeout: timeout, transport: transport)
    }

    func request<Request: MirakurunAPIRequest>(_ request: Request) async throws -> Request.Response.Value {
        try await executeAPIRequest(request, using: openAPI())
    }

    private func openAPI() throws -> MirakurunAPI.Client {
        MirakurunAPI.Client(
            serverURL: try recordingServerURL(host: host, defaultPort: Self.defaultPort, template: MirakurunAPI.Servers.Server1.url()),
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [OpenAPIResponseMiddleware(), OpenAPIJSONMiddleware()]
        )
    }

}
