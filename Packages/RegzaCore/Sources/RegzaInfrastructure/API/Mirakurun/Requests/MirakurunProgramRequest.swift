import MirakurunAPI

struct MirakurunProgramRequest: MirakurunAPIRequest {
    typealias Response = MirakurunProgramResponse

    let id: Int

    func send(using apiClient: MirakurunAPI.Client) async throws -> MirakurunAPI.Components.Schemas.Program {
        try await apiClient.getProgram(path: .init(id: id)).ok.body.json
    }
}
