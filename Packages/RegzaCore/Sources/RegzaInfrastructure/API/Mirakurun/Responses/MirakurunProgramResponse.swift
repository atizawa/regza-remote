import MirakurunAPI
import RegzaDomain

struct MirakurunProgramResponse: APIResponse {
    let value: ProgramData

    init(_ output: MirakurunAPI.Components.Schemas.Program) async throws {
        value = try MirakurunProgramMapper.program(output)
    }
}
