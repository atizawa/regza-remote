import RegzaDomain
import RegzaTVAPI

struct RegzaReservationsResponse: APIResponse {
    let value: [ReservationData]

    init(_ output: RegzaTVAPI.Components.Schemas.ReservationList) async throws {
        let list: RegzaReservationList = try RegzaDataMapper.model(from: output)
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        value = list.reservations ?? []
    }
}
