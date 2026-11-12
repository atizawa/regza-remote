import Foundation
import RegzaDomain
import RegzaTVAPI

/// REGZA の HTTP リモコン API クライアント。
///
/// - `GET /remote/remote.htm?key=XXXXXX` キー送信 (成功で `0`)
/// - `GET /remote/status.htm` 再生状況
/// - `GET /remote/ts.htm?SEC` シーク
///
/// いずれも Digest 認証が必要。PIN 登録は `RegzaPairing` を使う。
public actor RegzaAPIClient {
    public private(set) var connection: ConnectionData
    private let transport: any HTTPTransport
    private let timeout: TimeInterval
    private var digest: RegzaDigestMiddleware

    public init(connection: ConnectionData, timeout: TimeInterval = 3, transport: any HTTPTransport) {
        self.connection = connection
        self.timeout = timeout
        self.transport = transport
        self.digest = RegzaDigestMiddleware(connection: connection)
    }

    /// テレビの HTTPS のポート。録画予約の追加はこちらでしか受け付けない
    public static let securePort = 4430

    /// 接続確認などの独立した通信でも、注入された通信方式・タイムアウトを使う。
    public func replacingConnection(_ connection: ConnectionData) -> RegzaAPIClient {
        RegzaAPIClient(connection: connection, timeout: timeout, transport: transport)
    }

    public func update(connection: ConnectionData) {
        guard connection != self.connection else { return }
        self.connection = connection
        digest = RegzaDigestMiddleware(connection: connection)
    }

    func request<Request: RegzaAPIRequest>(_ request: Request) async throws -> Request.Response.Value {
        try await executeAPIRequest(request, using: openAPI(secure: request.usesSecureConnection, queryOverride: request.queryOverride))
    }

    private func openAPI(secure: Bool = false, queryOverride: String? = nil) throws -> Client {
        guard connection.isConfigured else { throw RegzaError.notConfigured }
        var host = connection.trimmedHost
        if !host.contains("://") { host = "http://" + host }
        while host.hasSuffix("/") { host.removeLast() }
        guard var components = URLComponents(string: host), components.host != nil else { throw RegzaError.invalidHost }
        if secure {
            components.scheme = "https"
            components.port = Self.securePort
        }
        guard let url = components.url else { throw RegzaError.invalidHost }
        return Client(
            serverURL: url,
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [
                OpenAPIResponseMiddleware(usesDigestAuthentication: true),
                RegzaCompatibilityMiddleware(queryOverride: queryOverride),
                digest,
            ]
        )
    }

}
