import EPGStationAPI

struct EPGStationVersionRequest: EPGStationAPIRequest {
    typealias Response = EPGStationVersionResponse

    func send(using client: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.Version {
        try await client.getVersion().ok.body.json
    }
}
