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
    /// 文言を引く code。いちばん詳しい code (codes の最初)
    public var code: ErrorCode { codes[0] }

    /// 文言を引く code を、詳しい順に並べたもの。表に当てはまるものがなければ、次の code で引く。
    /// API の問題は、API が決めた code (api の仲間)・type・HTTP のステータスの順。ほかは場合ごとに決めた code 1 つ
    public var codes: [ErrorCode] {
        guard case .problem(let problem) = self else { return [singleCode] }
        let candidates = [
            problem.code.map(ErrorCode.apiCode),
            problem.type == APIProblem.blankType ? nil : ErrorCode.problemType(problem.type),
            problem.status.map { ErrorCode.http.appending(String($0)) },
        ]
        let found = candidates.compactMap { $0 }
        return found.isEmpty ? ["problem"] : found
    }

    /// HTTP のステータス。API の問題の詳細で届いたときも含む (404 で分かれる処理は、これを見る)
    public var status: Int? {
        switch self {
        case .httpStatus(let status): status
        case .problem(let problem): problem.status
        default: nil
        }
    }

    /// 機種やサーバーがその機能に対応していない (対応していないことを伝える返事か、種類を書かない 404)。
    /// 種類 (type) や API の code の付いた 404 は、何かが見つからないなどの、見分けられたエラーなので含めない
    public var isUnsupported: Bool { self == .unsupported || self == .httpStatus(404) }

    /// 求めたものがもう無い (ステータスが 404。種類や API の code が付いていても)
    public var isNotFound: Bool { status == 404 }

    private var singleCode: ErrorCode {
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
        case .problem: "problem"
        }
    }
}

extension ErrorCode {
    /// HTTP のステータスの仲間 (http.404 など)
    public static let http: ErrorCode = "http"
    /// テレビが受け付けなかった仲間 (command_rejected.2 など)
    public static let commandRejected: ErrorCode = "command_rejected"
    public static let unsupported: ErrorCode = "unsupported"
    /// API が決めた code の仲間 (api.<code>。RFC 9457 の拡張メンバー)
    public static let api: ErrorCode = "api"
    /// URI でない種類 (type) の仲間 (type.<type>。RFC 9457 の相対参照)
    public static let problemTypes: ErrorCode = "type"

    /// API が決めた code。表に足すときも、これで作る
    public static func apiCode(_ code: String) -> ErrorCode {
        api.appending(escaped(code))
    }

    /// API の問題の種類 (type)。URI はそのまま (まったく同じときだけ当てはまる)、URI でなければ type の仲間にする
    /// (アプリが決めた仲間に紛れないように)。表に足すときも、これで作る
    public static func problemType(_ type: String) -> ErrorCode {
        let code = ErrorCode(rawValue: type)
        return code.isURI ? code : problemTypes.appending(escaped(type))
    }

    /// API の値を 1 つの階層にする。. (階層の区切り)・: (URI の印)・% は、ほかの値と重ならないよう % で書き換える
    private static func escaped(_ value: String) -> String {
        value.replacing("%", with: "%25").replacing(".", with: "%2E").replacing(":", with: "%3A")
    }
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
