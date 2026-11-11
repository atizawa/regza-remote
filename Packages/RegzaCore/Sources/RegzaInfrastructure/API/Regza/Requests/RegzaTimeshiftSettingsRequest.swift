import RegzaTVAPI

struct RegzaTimeshiftSettingsRequest: RegzaAPIRequest {
    typealias Response = RegzaTimeshiftSettingsResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.TimeshiftSettings {
        try await client.getTimeshiftSettings().ok.body.json
    }
}
