import RegzaTVAPI

struct RegzaTuneRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    let code: String

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await client.tune(body: .urlEncodedForm(.init(channel: code))).ok.body.json
    }
}
