import RegzaTVAPI

struct RegzaReservationsRequest: RegzaAPIRequest {
    typealias Response = RegzaReservationsResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.ReservationList {
        try await apiClient.getReservations().ok.body.json
    }
}
