import EPGStationAPI

struct EPGStationStopStreamRequest: EPGStationAPIRequest {
    typealias Response = NoContentAPIResponse

    let streamID: Int

    func send(using client: EPGStationAPI.Client) async throws {
        _ = try await client.stopStream(path: .init(streamId: streamID))
    }
}
