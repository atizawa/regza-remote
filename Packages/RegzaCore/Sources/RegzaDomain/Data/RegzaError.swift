import Foundation

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
        case .notConfigured: "接続先が設定されていません"
        case .invalidHost: "IPアドレスが正しくありません"
        case .unauthorized: "認証に失敗しました。ユーザー名とパスワードを確認してください"
        case .httpStatus(let code): "HTTPエラー (\(code))"
        case .commandRejected(let code): "テレビがコマンドを拒否しました (\(code))"
        case .unsupported: "この機種は対応していません"
        case .invalidPIN: "PIN が正しくありません。テレビに表示されている数字を確認してください"
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
