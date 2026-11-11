import RegzaTVAPI

struct RegzaConfirmPairingRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await apiClient.confirmConnection().ok.body.json
    }
}
