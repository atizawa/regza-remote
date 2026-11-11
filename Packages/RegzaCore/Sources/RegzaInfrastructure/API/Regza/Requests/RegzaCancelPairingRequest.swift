import RegzaTVAPI

struct RegzaCancelPairingRequest: RegzaAPIRequest {
    typealias Response = NoContentAPIResponse

    let user: String

    func send(using apiClient: RegzaTVAPI.Client) async throws {
        _ = try await apiClient.cancelConnection(body: .urlEncodedForm(.init(user_id: user)))
    }
}
