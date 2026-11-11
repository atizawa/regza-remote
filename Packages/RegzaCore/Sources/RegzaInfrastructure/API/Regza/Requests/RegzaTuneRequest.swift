import RegzaTVAPI

struct RegzaTuneRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    let code: String

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await apiClient.tune(body: .urlEncodedForm(.init(channel: code))).ok.body.json
    }
}
