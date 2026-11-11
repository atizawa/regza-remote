import RegzaTVAPI

struct RegzaPlayStatusRequest: RegzaAPIRequest {
    typealias Response = RegzaPlayStatusResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.PlayStatus {
        try await client.getPlayStatus().ok.body.json
    }
}
