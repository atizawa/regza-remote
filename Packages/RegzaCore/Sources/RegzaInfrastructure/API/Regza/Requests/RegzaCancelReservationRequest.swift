import RegzaTVAPI

struct RegzaCancelReservationRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    let id: String

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await apiClient.cancelReservation(path: .init(rsv_id: id)).ok.body.json
    }
}
