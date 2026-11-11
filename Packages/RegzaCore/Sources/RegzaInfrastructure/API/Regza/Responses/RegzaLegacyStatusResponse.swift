import Foundation
import OpenAPIRuntime

struct RegzaLegacyStatusResponse: APIResponse {
    let value: RegzaStatus

    init(_ output: HTTPBody) async throws {
        value = RegzaStatus(text: RegzaResponseDecoding.text(try await Data(collecting: output, upTo: 1024 * 1024)))
    }
}
