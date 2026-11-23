public import AppErrors
import Foundation
internal import RegzaStrings

/// このアプリのエラー。共通の失敗 (AppError) に、このアプリ固有の失敗 (RegzaFailure) を入れる
public typealias RegzaError = AppError<RegzaFailure>

/// このアプリ固有の失敗 (接続先の設定とテレビとのやり取り)。雛形として使うときは、この型を入れ替える
public enum RegzaFailure: AppSpecificError {
    /// 接続先が設定されていない
    case notConfigured
    /// 接続先のアドレスが正しくない
    case invalidHost
    /// テレビが受け付けなかった (remote.htm が 0 以外を返した)
    case commandRejected(String)
    /// 機種が API に対応していない
    case unsupported
    /// PIN 登録で PIN が違う
    case invalidPIN

    public var code: ErrorCode {
        switch self {
        case .notConfigured: "not_configured"
        case .invalidHost: "invalid_host"
        case .commandRejected(let code): ErrorCode.commandRejected.appending(code)
        case .unsupported: .unsupported
        case .invalidPIN: "invalid_pin"
        }
    }

    public var message: String {
        switch self {
        case .notConfigured: CoreStrings.errorNotConfigured
        case .invalidHost: CoreStrings.errorInvalidHost
        case .commandRejected(let code): CoreStrings.errorCommandRejected(code)
        case .unsupported: CoreStrings.errorUnsupported
        case .invalidPIN: CoreStrings.errorInvalidPin
        }
    }
}

extension AppError where Specific == RegzaFailure {
    /// 機種やサーバーがその機能に対応していない (対応していないことを伝える返事か、種類も API の code もない 404)。
    /// 種類 (type) や API の code の付いた 404 は、何かが見つからないなどの、見分けられたエラーなので含めない
    public var isUnsupported: Bool { self == .app(.unsupported) || isUnidentifiedNotFound }
}

extension ErrorCode {
    /// テレビが受け付けなかった仲間 (command_rejected.<テレビが返した値>)
    public static let commandRejected: ErrorCode = "command_rejected"
    public static let unsupported: ErrorCode = "unsupported"
    /// 配信の準備ができなかった
    public static let streamUnavailable: ErrorCode = "stream_unavailable"
    /// ロック画面の表示を始められなかった
    public static let lockScreenStartFailed: ErrorCode = "lock_screen_start_failed"
}
