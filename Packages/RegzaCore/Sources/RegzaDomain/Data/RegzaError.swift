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
    /// アプリが決めた code の失敗 (配信の準備ができないなど)。文言は画面に出すときに code で引く
    case failed(ErrorCode)
    /// 通信が返事を受け取れなかった
    case connection(ConnectionFailure)
    /// HTTP API が返したエラーの詳細 (RFC 9457)
    case problem(APIProblem)
}

extension RegzaError {
    /// 文言を引く code。API の問題はその type (about:blank なら HTTP のステータス)、ほかは場合ごとに決めた code
    public var code: ErrorCode {
        switch self {
        case .notConfigured: "not_configured"
        case .invalidHost: "invalid_host"
        case .unauthorized: "unauthorized"
        case .httpStatus(let status): ErrorCode.http.appending(String(status))
        case .commandRejected(let code): ErrorCode.commandRejected.appending(code)
        case .unsupported: "unsupported"
        case .invalidPIN: "invalid_pin"
        case .failed(let code): code
        case .connection(let failure): ErrorCode.connection.appending(failure.rawValue)
        case .problem(let problem):
            problem.type == APIProblem.blankType
                ? problem.status.map { ErrorCode.http.appending(String($0)) } ?? "problem"
                : ErrorCode(rawValue: problem.type)
        }
    }
}

extension ErrorCode {
    /// HTTP のステータスの仲間 (http.404 など)
    public static let http: ErrorCode = "http"
    /// テレビが受け付けなかった仲間 (command_rejected.2 など)
    public static let commandRejected: ErrorCode = "command_rejected"
    public static let unsupported: ErrorCode = "unsupported"
    /// 通信が返事を受け取れなかった仲間 (connection.timed_out など)
    public static let connection: ErrorCode = "connection"
    /// 配信の準備ができなかった
    public static let streamUnavailable: ErrorCode = "stream_unavailable"
    /// ロック画面の表示を始められなかった
    public static let lockScreenStartFailed: ErrorCode = "lock_screen_start_failed"
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
        case .failed: CoreStrings.errorFailed
        case .connection(let failure):
            switch failure {
            case .cannotConnect: CoreStrings.errorConnectionCannotConnect
            case .timedOut: CoreStrings.errorConnectionTimedOut
            case .certificate: CoreStrings.errorConnectionCertificate
            case .offline: CoreStrings.errorConnectionOffline
            case .cancelled: CoreStrings.errorRequestCancelled
            case .invalidResponse: CoreStrings.errorInvalidResponse
            case .other: CoreStrings.errorConnectionFailed
            }
        // サーバーの title・detail は言語や言い方がアプリと合うとは限らないので出さず、アプリの言い方にする
        case .problem(let problem): problem.status.map(CoreStrings.errorHttpStatus) ?? CoreStrings.errorProblem
        }
    }
}

extension RegzaError {
    /// RegzaError 以外のエラーは、通信が返事を受け取れなかったものとして扱う (OS の文言は使わない)。
    /// 処理を途中で止めたときは、取り消したものとして扱う
    public init(_ error: any Error) {
        self = error as? RegzaError ?? (error is CancellationError ? .connection(.cancelled) : .connection(.other))
    }
}
