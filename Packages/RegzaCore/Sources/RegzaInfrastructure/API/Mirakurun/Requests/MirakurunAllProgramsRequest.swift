import MirakurunAPI

struct MirakurunAllProgramsRequest: MirakurunAPIRequest {
    typealias Response = MirakurunProgramsResponse

    func send(using apiClient: MirakurunAPI.Client) async throws -> [MirakurunAPI.Components.Schemas.Program] {
        try await apiClient.getPrograms().ok.body.json
    }
}
