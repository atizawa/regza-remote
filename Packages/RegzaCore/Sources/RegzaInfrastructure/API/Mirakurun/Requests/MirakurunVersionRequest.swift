import MirakurunAPI

struct MirakurunVersionRequest: MirakurunAPIRequest {
    typealias Response = MirakurunVersionResponse

    func send(using apiClient: MirakurunAPI.Client) async throws -> MirakurunAPI.Components.Schemas.Version {
        try await apiClient.checkVersion().ok.body.json
    }
}
