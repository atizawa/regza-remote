import Foundation

/// 同じネットワークで見つかったテレビ (UI で使う形)。SetupUseCase が Domain の RegzaDevice から作る
public struct DeviceItem: Equatable, Sendable, Identifiable {
    public var host: String
    /// 「REGZA 55Z000」
    public var name: String
    /// PIN 登録 (レグザAppsコネクト v2) に対応しているか
    public var supportsPIN: Bool
    /// いま選んでいる (入力中のアドレスと同じ)
    public var isSelected: Bool
    public var id: String { host }

    public init(host: String, name: String, supportsPIN: Bool, isSelected: Bool = false) {
        self.host = host
        self.name = name
        self.supportsPIN = supportsPIN
        self.isSelected = isSelected
    }
}
