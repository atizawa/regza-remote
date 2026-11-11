import OpenAPIRuntime
import RegzaTVAPI

struct RegzaLegacyStatusRequest: RegzaAPIRequest {
    typealias Response = RegzaLegacyStatusResponse

    func send(using apiClient: RegzaTVAPI.Client) async throws -> HTTPBody {
        try await apiClient.getLegacyStatus().ok.body.plainText
    }
}
