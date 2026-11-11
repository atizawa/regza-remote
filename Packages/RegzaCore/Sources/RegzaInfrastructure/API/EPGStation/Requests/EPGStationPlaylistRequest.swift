import Foundation
import RegzaDomain

/// HLS プレイリストは OpenAPI の REST 操作とは別のファイル取得。
struct EPGStationPlaylistRequest: APIRequest {
    struct Context: Sendable {
        let baseURL: URL
        let transport: any HTTPTransport
        let timeout: TimeInterval
    }

    typealias Client = Context
    typealias Response = EPGStationPlaylistResponse
    let streamID: Int

    func url(baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw RegzaError.invalidHost
        }
        components.path = "/streamfiles/stream\(streamID).m3u8"
        guard let url = components.url else { throw RegzaError.invalidHost }
        return url
    }

    func send(using client: Context) async throws -> HTTPResponse {
        try await client.transport.send(HTTPRequest(url: url(baseURL: client.baseURL), timeout: client.timeout))
    }
}
