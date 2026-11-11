import OpenAPIRuntime
import RegzaTVAPI

struct RegzaLegacyStatusRequest: RegzaAPIRequest {
    typealias Response = RegzaLegacyStatusResponse

    func send(using client: RegzaTVAPI.Client) async throws -> HTTPBody {
        try await client.getLegacyStatus().ok.body.plainText
    }
}
