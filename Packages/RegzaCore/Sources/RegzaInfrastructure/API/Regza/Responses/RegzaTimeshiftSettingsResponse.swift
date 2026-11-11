import RegzaDomain
import RegzaTVAPI

struct RegzaTimeshiftSettingsResponse: APIResponse {
    let value: RegzaTimeshiftSettings

    init(_ output: RegzaTVAPI.Components.Schemas.TimeshiftSettings) async throws {
        value = try RegzaResponseDecoding.model(from: output)
    }
}
