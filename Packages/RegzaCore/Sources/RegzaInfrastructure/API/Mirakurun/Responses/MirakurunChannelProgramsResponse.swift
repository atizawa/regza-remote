import MirakurunAPI
import RegzaDomain

struct MirakurunChannelProgramsResponse: APIResponse {
    let value: [ProgramData]

    init(_ output: [MirakurunAPI.Components.Schemas.Program]) async throws {
        value = try output.map(MirakurunProgramMapper.program).sorted { $0.start < $1.start }
    }
}
