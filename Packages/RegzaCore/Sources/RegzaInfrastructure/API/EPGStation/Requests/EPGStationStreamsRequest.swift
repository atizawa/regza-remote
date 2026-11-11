import EPGStationAPI

struct EPGStationStreamsRequest: EPGStationAPIRequest {
    typealias Response = EPGStationStreamsResponse

    func send(using apiClient: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.StreamInfo {
        try await apiClient.getStreams(query: .init(isHalfWidth: true)).ok.body.json
    }
}
