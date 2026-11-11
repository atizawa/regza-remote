import EPGStationAPI

struct EPGStationStartStreamRequest: EPGStationAPIRequest {
    typealias Response = EPGStationStartStreamResponse

    let channelID: Int
    let mode: Int

    func send(using apiClient: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.StartStreamInfo {
        try await apiClient.startLiveStream(path: .init(channelId: channelID), query: .init(mode: mode)).ok.body.json
    }
}
