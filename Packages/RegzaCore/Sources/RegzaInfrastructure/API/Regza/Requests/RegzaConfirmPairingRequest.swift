import RegzaTVAPI

struct RegzaConfirmPairingRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await client.confirmConnection().ok.body.json
    }
}
