import Foundation
import RegzaTVAPI

struct RegzaReserveRequest: RegzaAPIRequest {
    typealias Response = RegzaResultResponse

    let channel: String
    let epgContentID: String
    let start: Date
    let duration: Int
    let series: Bool
    var usesSecureConnection: Bool { true }

    func send(using client: RegzaTVAPI.Client) async throws -> RegzaTVAPI.Components.Schemas.Result {
        try await client.addReservation(
            body: .urlEncodedForm(
                .init(
                    channel: channel, epg_content_id: epgContentID, start_time: Int(start.timeIntervalSince1970), duration: duration,
                    series_rec: series ? ._true : nil))
        ).ok.body.json
    }
}
