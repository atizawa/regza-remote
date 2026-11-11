import OpenAPIRuntime
import RegzaDomain
import RegzaTVAPI

struct RegzaSendKeyRequest: RegzaAPIRequest {
    typealias Response = RegzaSendKeyResponse

    let key: RegzaKey

    func send(using client: RegzaTVAPI.Client) async throws -> HTTPBody {
        try await client.sendKey(query: .init(key: key.code)).ok.body.plainText
    }
}
