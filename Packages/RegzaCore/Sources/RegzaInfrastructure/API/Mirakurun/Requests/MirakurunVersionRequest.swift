import MirakurunAPI

struct MirakurunVersionRequest: MirakurunAPIRequest {
    typealias Response = MirakurunVersionResponse

    func send(using client: MirakurunAPI.Client) async throws -> MirakurunAPI.Components.Schemas.Version {
        try await client.checkVersion().ok.body.json
    }
}
