import Foundation

/// 同じネットワークにある REGZA。
public struct DeviceData: Hashable, Sendable, Identifiable {
    public var host: String
    public var model: String
    public var size: String
    /// PIN 登録 (レグザAppsコネクト v2) に対応しているか
    public var supportsPIN: Bool

    public init(host: String, model: String, size: String, supportsPIN: Bool) {
        self.host = host
        self.model = model
        self.size = size
        self.supportsPIN = supportsPIN
    }

    public var id: String { host }

    /// 例: `REGZA 55Z000`
    public var name: String { "REGZA \(size)\(model)" }
}
