/// アプリの外観。systemはOSの設定に追従する。
public enum AppAppearance: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}
