import OpenAPIRuntime
import RegzaDomain
import RegzaTVAPI

struct RegzaSendKeyRequest: RegzaAPIRequest {
    typealias Response = RegzaSendKeyResponse

    let key: RegzaKey

    func send(using apiClient: RegzaTVAPI.Client) async throws -> HTTPBody {
        try await apiClient.sendKey(query: .init(key: key.code)).ok.body.plainText
    }
}
