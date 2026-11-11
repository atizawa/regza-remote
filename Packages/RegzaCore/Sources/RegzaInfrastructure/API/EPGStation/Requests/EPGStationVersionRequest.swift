import EPGStationAPI

struct EPGStationVersionRequest: EPGStationAPIRequest {
    typealias Response = EPGStationVersionResponse

    func send(using apiClient: EPGStationAPI.Client) async throws -> EPGStationAPI.Components.Schemas.Version {
        try await apiClient.getVersion().ok.body.json
    }
}
