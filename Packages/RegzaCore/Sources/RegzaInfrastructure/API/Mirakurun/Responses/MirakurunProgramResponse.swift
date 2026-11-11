import MirakurunAPI
import RegzaDomain

struct MirakurunProgramResponse: APIResponse {
    let value: MirakurunProgram

    init(_ output: MirakurunAPI.Components.Schemas.Program) async throws {
        value = try MirakurunProgramMapper.program(output)
    }
}
