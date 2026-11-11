import EPGStationAPI

struct EPGStationKeepStreamRequest: EPGStationAPIRequest {
    typealias Response = NoContentAPIResponse

    let streamID: Int

    func send(using apiClient: EPGStationAPI.Client) async throws {
        _ = try await apiClient.keepStream(path: .init(streamId: streamID))
    }
}
