import RegzaDomain
import RegzaTVAPI

struct RegzaTimeshiftSettingsResponse: APIResponse {
    let value: TimeshiftSettingsData

    init(_ output: RegzaTVAPI.Components.Schemas.TimeshiftSettings) async throws {
        value = try RegzaDataMapper.model(from: output)
    }
}
