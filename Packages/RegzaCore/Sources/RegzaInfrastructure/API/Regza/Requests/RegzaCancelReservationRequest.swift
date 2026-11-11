import RegzaTVAPI

struct RegzaCancelReservationRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    let id: String

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await client.cancelReservation(path: .init(rsv_id: id)).ok.body.json
    }
}
