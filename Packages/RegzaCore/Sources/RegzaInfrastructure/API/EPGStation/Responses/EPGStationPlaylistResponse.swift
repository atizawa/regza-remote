import Foundation
import RegzaDomain

struct EPGStationPlaylistResponse: APIResponse {
    let value: Bool

    init(_ output: HTTPResponse) async throws {
        guard (200..<300).contains(output.statusCode) else { throw RegzaError.httpStatus(output.statusCode) }
        value = String(decoding: output.body, as: UTF8.self).contains(".ts")
    }
}
