import Foundation

/// REGZA への接続情報。
public struct RegzaConnection: Equatable, Sendable {
    public var host: String
    public var user: String
    public var password: String

    public init(host: String = "", user: String = "", password: String = "") {
        self.host = host
        self.user = user
        self.password = password
    }

    public var isConfigured: Bool { !trimmedHost.isEmpty }

    var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// 接続情報の永続化。プラットフォームごとに実装する
/// (iOS はキーチェーン、Android は SharedPreferences など)。
public protocol RegzaConnectionStore: Sendable {
    func load() -> RegzaConnection
    func save(_ connection: RegzaConnection)
}
