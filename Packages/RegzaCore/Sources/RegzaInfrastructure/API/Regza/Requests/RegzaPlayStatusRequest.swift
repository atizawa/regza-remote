import RegzaTVAPI

struct RegzaPlayStatusRequest: RegzaAPIRequest {
    typealias Response = RegzaPlayStatusResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.PlayStatus {
        try await apiClient.getPlayStatus().ok.body.json
    }
}
