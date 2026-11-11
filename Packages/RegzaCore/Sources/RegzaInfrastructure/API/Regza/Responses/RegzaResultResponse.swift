import RegzaDomain
import RegzaTVAPI

struct RegzaResultResponse: APIResponse {
    let value: Void

    init(_ output: RegzaTVAPI.Components.Schemas.Result) async throws {
        guard output.status == 0 else { throw RegzaError.commandRejected(String(output.status)) }
        value = ()
    }
}
