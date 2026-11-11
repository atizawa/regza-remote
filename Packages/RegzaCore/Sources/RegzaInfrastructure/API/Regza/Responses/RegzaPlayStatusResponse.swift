import RegzaDomain
import RegzaTVAPI

struct RegzaPlayStatusResponse: APIResponse {
    let value: RegzaPlayStatus

    init(_ output: RegzaTVAPI.Components.Schemas.PlayStatus) async throws {
        let status: RegzaPlayStatus = try RegzaResponseDecoding.model(from: output)
        guard status.status == 0 else { throw RegzaError.commandRejected(String(status.status)) }
        value = status
    }
}
