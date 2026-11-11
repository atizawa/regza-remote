import EPGStationAPI

struct EPGStationStopStreamRequest: EPGStationAPIRequest {
    typealias Response = NoContentAPIResponse

    let streamID: Int

    func send(using apiClient: EPGStationAPI.Client) async throws {
        _ = try await apiClient.stopStream(path: .init(streamId: streamID))
    }
}
