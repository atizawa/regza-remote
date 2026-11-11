import RegzaTVAPI

struct RegzaReservationsRequest: RegzaAPIRequest {
    typealias Response = RegzaReservationsResponse

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.ReservationList {
        try await client.getReservations().ok.body.json
    }
}
