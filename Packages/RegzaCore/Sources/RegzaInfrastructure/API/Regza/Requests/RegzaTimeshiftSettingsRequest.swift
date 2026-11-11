import RegzaTVAPI

struct RegzaTimeshiftSettingsRequest: RegzaAPIRequest {
    typealias Response = RegzaTimeshiftSettingsResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.TimeshiftSettings {
        try await apiClient.getTimeshiftSettings().ok.body.json
    }
}
