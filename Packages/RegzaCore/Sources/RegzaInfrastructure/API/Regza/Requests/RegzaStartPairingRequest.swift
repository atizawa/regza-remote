import RegzaTVAPI

struct RegzaStartPairingRequest: RegzaAPIRequest {
    typealias Response = RegzaPairingChallengeResponse

    let user: String

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.ConnectionChallenge {
        try await client.requestConnection(body: .urlEncodedForm(.init(user_id: user))).ok.body.json
    }
}
