import Foundation
import OpenAPIRuntime
import RegzaDomain
import RegzaTVAPI

extension RegzaAPIClient {
    func featureData() async throws -> Data {
        try await generated { try await JSONEncoder().encode(openAPI().getFeature().ok.body.json) }
    }

    func startPairing(user: String) async throws -> Data {
        try await generated {
            try await JSONEncoder().encode(openAPI().requestConnection(body: .urlEncodedForm(.init(user_id: user))).ok.body.json)
        }
    }

    func confirmPairing() async throws -> Data {
        try await generated { try await JSONEncoder().encode(openAPI().confirmConnection().ok.body.json) }
    }

    func cancelPairing(user: String) async throws {
        _ = try await generated { try await openAPI().cancelConnection(body: .urlEncodedForm(.init(user_id: user))) }
    }

    /// 通信層のエラーは既存の公開契約を保つ。仕様外の本文は未対応の機種として扱う。
    func generated<Value>(_ operation: () async throws -> Value) async throws -> Value {
        try await performOpenAPI(operation)
    }
}
