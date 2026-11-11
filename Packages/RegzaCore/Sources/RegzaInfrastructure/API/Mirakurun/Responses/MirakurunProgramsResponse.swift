import MirakurunAPI
import RegzaDomain

struct MirakurunProgramsResponse: APIResponse {
    let value: [MirakurunProgram]

    init(_ output: [MirakurunAPI.Components.Schemas.Program]) async throws {
        value = try output.map(MirakurunProgramMapper.program)
    }
}
