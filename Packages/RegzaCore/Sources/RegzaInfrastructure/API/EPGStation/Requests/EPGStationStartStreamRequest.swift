import EPGStationAPI

struct EPGStationStartStreamRequest: EPGStationAPIRequest {
    typealias Response = EPGStationStartStreamResponse

    let channelID: Int
    let mode: Int

    func send(using client: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.StartStreamInfo {
        try await client.startLiveStream(path: .init(channelId: channelID), query: .init(mode: mode)).ok.body.json
    }
}
