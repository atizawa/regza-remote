import Foundation
import RegzaDomain

struct EPGStationStreaming {
    let epgStationAPIClient: EPGStationAPIClient
    func playlistURL(streamID: Int) -> URL? {
        guard let context = try? epgStationAPIClient.playlistContext() else { return nil }
        return try? EPGStationPlaylistRequest(streamID: streamID).url(baseURL: context.baseURL)
    }

    /// 再生できるまで keep を送りながら待つ。
    func waitUntilReady(streamID: Int, timeout: TimeInterval = 60) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if (try? await executeAPIRequest(EPGStationPlaylistRequest(streamID: streamID), using: epgStationAPIClient.playlistContext()))
                == true
            {
                return
            }
            try? await epgStationAPIClient.request(EPGStationKeepStreamRequest(streamID: streamID))
            try await Task.sleep(for: .seconds(1))
        }
        throw RegzaError.network("配信の準備ができませんでした")
    }
}
