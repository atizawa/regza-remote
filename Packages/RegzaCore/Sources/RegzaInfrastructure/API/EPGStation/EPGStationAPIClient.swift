import EPGStationAPI
import Foundation
import RegzaDomain

/// 録画サーバー EPGStation の放送のライブ配信 (HLS)。認証は不要。
///
/// 1. `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼むと番号 (streamId) が返る
/// 2. 変換が始まるまで十数秒かかる。`/streamfiles/stream{番号}.m3u8` に映像の部分 (.ts) が載ったら再生できる
/// 3. 見ている間は `PUT /api/streams/:id/keep` で知らせ、終わったら `DELETE /api/streams/:id` で止めてチューナーを空ける
///
/// 同時に変換できる数に上限がある構成では、上限に達していると配信が始まらない (準備できないまま残る)
public final class EPGStationAPIClient: Sendable {
    public static let defaultPort = ServerPort.epgStation

    /// `192.168.0.2` か `192.168.0.2:8888`
    public let host: String
    private let timeout: TimeInterval
    private let transport: any HTTPTransport

    public init(host: String, timeout: TimeInterval = 10, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
        self.transport = transport
    }

    /// 注入された通信方式とタイムアウトを保ったまま接続先を差し替える。
    public func replacingHost(_ host: String) -> EPGStationAPIClient {
        EPGStationAPIClient(host: host, timeout: timeout, transport: transport)
    }

    func request<Request: EPGStationAPIRequest>(_ request: Request) async throws -> Request.Response.Value {
        try await executeAPIRequest(request, using: openAPI())
    }

    func playlistContext() throws -> EPGStationPlaylistRequest.Context {
        .init(
            baseURL: try recordingServerURL(host: host, defaultPort: Self.defaultPort, template: EPGStationAPI.Servers.Server1.url()),
            transport: transport, timeout: timeout
        )
    }

    private func openAPI() throws -> EPGStationAPI.Client {
        EPGStationAPI.Client(
            serverURL: try recordingServerURL(host: host, defaultPort: Self.defaultPort, template: EPGStationAPI.Servers.Server1.url()),
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [OpenAPIResponseMiddleware(), OpenAPIJSONMiddleware()]
        )
    }

}
