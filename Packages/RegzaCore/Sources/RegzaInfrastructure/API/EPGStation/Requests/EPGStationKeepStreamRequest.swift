import EPGStationAPI

struct EPGStationKeepStreamRequest: EPGStationAPIRequest {
    typealias Response = NoContentAPIResponse

    let streamID: Int

    func send(using client: EPGStationAPI.Client) async throws {
        _ = try await client.keepStream(path: .init(streamId: streamID))
    }
}
