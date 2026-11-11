import MirakurunAPI
import RegzaDomain

struct MirakurunProgramsResponse: APIResponse {
    let value: [ProgramData]

    init(_ output: [MirakurunAPI.Components.Schemas.Program]) async throws {
        value = try output.map(MirakurunProgramMapper.program)
    }
}
