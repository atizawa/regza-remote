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

    public var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
}
