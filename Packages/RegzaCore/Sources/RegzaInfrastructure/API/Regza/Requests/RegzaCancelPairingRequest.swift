import RegzaTVAPI

struct RegzaCancelPairingRequest: RegzaAPIRequest {
    typealias Response = NoContentAPIResponse

    let user: String

    func send(using client: RegzaTVAPI.Client) async throws {
        _ = try await client.cancelConnection(body: .urlEncodedForm(.init(user_id: user)))
    }
}
