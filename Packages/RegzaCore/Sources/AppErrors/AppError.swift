import Foundation
internal import RegzaStrings

/// アプリ固有の失敗 (アプリのドメインで決める失敗)。文言を引く code と、表に言い換えがないときの文言を決める。
/// それだけでは投げられない (Error にしない) ので、いつも AppError の app に入れて投げる (読む側が場所ごとに食い違わないように)
public protocol AppSpecificError: Equatable, Sendable {
    /// 文言を引く code。共通の仲間 (`AppError.commonFamilies`) には入れない (入れると、共通の失敗の言い換えが当てはまってしまう)
    var code: ErrorCode { get }
    /// 表に言い換えがないときの文言
    var message: String { get }
}

/// アプリのエラー。どのアプリにも共通の失敗 (通信・HTTP・API の問題・アプリが決めた code) と、アプリ固有の失敗 (Specific) に分ける。
/// 雛形として使うときは、Specific だけを入れ替える
public enum AppError<Specific: AppSpecificError>: Error, Equatable, Sendable {
    /// 認証できなかった
    case unauthorized
    /// HTTP のステータスが成功でなかった (種類の分かる詳細がないとき)
    case httpStatus(Int)
    /// 通信が返事を受け取れなかった
    case connection(ConnectionFailure)
    /// HTTP API が返したエラーの詳細 (RFC 9457)
    case problem(APIProblem)
    /// アプリが決めた code の失敗。文言は画面に出すときに code で引く
    case failed(ErrorCode)
    /// アプリ固有の失敗
    case app(Specific)
}

extension AppError {
    /// 文言を引く code。いちばん詳しい code (codes の最初)
    public var code: ErrorCode { codes[0] }

    /// 文言を引く code を、詳しい順に並べたもの。表に当てはまるものがなければ、次の code で引く。
    /// API の問題は、API が決めた code (api の仲間)・type・HTTP のステータスの順。ほかは場合ごとに決めた code 1 つ
    public var codes: [ErrorCode] {
        switch self {
        case .unauthorized: [.unauthorized]
        case .httpStatus(let status): [.httpStatus(status)]
        case .connection(let failure): [ErrorCode.connection.appending(failure.rawValue)]
        case .failed(let code): [code]
        case .app(let specific): [specific.code]
        case .problem(let problem): Self.codes(of: problem)
        }
    }

    private static func codes(of problem: APIProblem) -> [ErrorCode] {
        let found = [
            problem.code.map(ErrorCode.apiCode),
            problem.type == APIProblem.blankType ? nil : ErrorCode.problemType(problem.type),
            problem.status.map(ErrorCode.httpStatus),
        ].compactMap { $0 }
        return found.isEmpty ? [.problem] : found
    }

    /// HTTP のステータス。API の問題の詳細で届いたときも含む。
    /// ステータスで分かれる決まりは、どのアプリにも共通ならここに、アプリ固有ならアプリの側に置き、これを見る
    public var status: Int? {
        switch self {
        case .httpStatus(let status): status
        case .problem(let problem): problem.status
        default: nil
        }
    }

    /// 求めたものがもう無い (ステータスが 404。種類や API の code が付いていても)
    public var isNotFound: Bool { status == 404 }

    /// 種類 (type) も API の code も付いていない 404 (HTTP のステータスだけのエラーか、見分けられない問題の詳細)。
    /// 何が見つからないのかを API が言っていないので、機能がないもの (対応していない) とみなすときに使う
    public var isUnidentifiedNotFound: Bool {
        switch self {
        case .httpStatus(404): true
        case .problem(let problem): !problem.isIdentified && problem.status == 404
        default: false
        }
    }
}

extension AppError {
    /// 共通の失敗が使う code とその仲間。アプリ固有の失敗の code は、ここに入れない
    public static var commonFamilies: [ErrorCode] { [.unauthorized, .http, .connection, .problem, .api, .problemTypes] }
}

extension ErrorCode {
    /// 認証できなかった
    public static let unauthorized: ErrorCode = "unauthorized"
    /// HTTP のステータスの仲間 (http.<ステータス>)
    public static let http: ErrorCode = "http"

    /// HTTP のステータスの code。表に足すときも、これで作る
    public static func httpStatus(_ status: Int) -> ErrorCode {
        http.appending(String(status))
    }
    /// 種類もステータスも分からない API の問題
    public static let problem: ErrorCode = "problem"
    /// 通信が返事を受け取れなかった仲間 (connection.<ConnectionFailure の値>)
    public static let connection: ErrorCode = "connection"
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
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized: CoreStrings.errorUnauthorized
        case .httpStatus(let code): CoreStrings.errorHttpStatus(code)
        case .failed: CoreStrings.errorFailed
        case .app(let specific): specific.message
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

extension AppError {
    /// アプリのエラー以外のエラーは、通信が返事を受け取れなかったものとして扱う (OS の文言は使わない)。
    /// 処理を途中で止めたときは、取り消したものとして扱う
    public init(_ error: any Error) {
        self = error as? Self ?? (error is CancellationError ? .connection(.cancelled) : .connection(.other))
    }
}
