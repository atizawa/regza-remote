import MirakurunAPI

struct MirakurunProgramRequest: MirakurunAPIRequest {
    typealias Response = MirakurunProgramResponse

    let id: Int

    func send(using client: MirakurunAPI.Client) async throws -> MirakurunAPI.Components.Schemas.Program {
        try await client.getProgram(path: .init(id: id)).ok.body.json
    }
}
