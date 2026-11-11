import Foundation

/// 接続設定・登録結果。保存用の ConnectionData は UseCase 内で変換する。
public struct ConnectionItem: Equatable, Sendable {
    public var host: String
    public var user: String
    public var password: String

    public init(host: String = "", user: String = "", password: String = "") {
        self.host = host
        self.user = user
        self.password = password
    }

    public var isConfigured: Bool { !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
