import EPGStationAPI

struct EPGStationStreamsRequest: EPGStationAPIRequest {
    typealias Response = EPGStationStreamsResponse

    func send(using client: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.StreamInfo {
        try await client.getStreams(query: .init(isHalfWidth: true)).ok.body.json
    }
}
