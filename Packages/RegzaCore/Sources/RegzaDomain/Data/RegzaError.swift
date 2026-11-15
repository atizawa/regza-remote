import Foundation
internal import RegzaStrings

public enum RegzaError: Error, Equatable, Sendable {
    case notConfigured
    case invalidHost
    case unauthorized
    case httpStatus(Int)
    /// remote.htm が 0 以外を返した
    case commandRejected(String)
    /// 機種が API に対応していない
    case unsupported
    /// PIN 登録で PIN が違う
    case invalidPIN
    case network(String)
}

extension RegzaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured: CoreStrings.errorNotConfigured
        case .invalidHost: CoreStrings.errorInvalidHost
        case .unauthorized: CoreStrings.errorUnauthorized
        case .httpStatus(let code): CoreStrings.errorHttpStatus(code)
        case .commandRejected(let code): CoreStrings.errorCommandRejected(code)
        case .unsupported: CoreStrings.errorUnsupported
        case .invalidPIN: CoreStrings.errorInvalidPin
        case .network(let message): message
        }
    }
}

extension RegzaError {
    /// RegzaError 以外のエラーは通信のエラーとして扱う
    public init(_ error: any Error) {
        self = error as? RegzaError ?? .network(error.localizedDescription)
    }
}
