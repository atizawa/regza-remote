import MirakurunAPI

struct MirakurunAllProgramsRequest: MirakurunAPIRequest {
    typealias Response = MirakurunProgramsResponse

    func send(using client: MirakurunAPI.Client) async throws -> [MirakurunAPI.Components.Schemas.Program] {
        try await client.getPrograms().ok.body.json
    }
}
