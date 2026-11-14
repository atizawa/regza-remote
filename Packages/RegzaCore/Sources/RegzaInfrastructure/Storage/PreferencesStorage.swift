/// OS ごとの設定値の保存先。配列などの形式は Manager が変換する。
public protocol PreferencesStorage: Sendable {
    func value(forKey key: PreferencesKey) -> String?
    func setValue(_ value: String, forKey key: PreferencesKey)
}

public enum PreferencesKey: String, CaseIterable, Sendable {
    case host
    case user
    case guideHost
    case streamHost
    case ownStreamIDs
    case appearance
}
