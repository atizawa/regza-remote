import Foundation
import OpenAPIRuntime
import RegzaDomain

struct RegzaSendKeyResponse: APIResponse {
    let value: Void

    init(_ output: HTTPBody) async throws {
        let text = RegzaResponseDecoding.text(try await Data(collecting: output, upTo: 1024 * 1024)).trimmingCharacters(
            in: .whitespacesAndNewlines)
        if let code = Int(text), code != 0 { throw RegzaError.commandRejected(text) }
        value = ()
    }
}
