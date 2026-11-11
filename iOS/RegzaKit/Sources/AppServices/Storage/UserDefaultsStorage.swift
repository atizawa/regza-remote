import Foundation
import RegzaInfrastructure

/// 既存のキーと配列の保存形式を保つ UserDefaults のアダプター。
public final class UserDefaultsStorage: PreferencesStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func value(forKey key: PreferencesKey) -> String? {
        if key == .ownStreamIDs {
            return (defaults.array(forKey: name(key)) as? [Int]).map { $0.map(String.init).joined(separator: ",") }
        }
        return defaults.string(forKey: name(key))
    }

    public func setValue(_ value: String, forKey key: PreferencesKey) {
        if key == .ownStreamIDs {
            defaults.set(value.split(separator: ",").compactMap { Int($0) }, forKey: name(key))
        } else {
            defaults.set(value, forKey: name(key))
        }
    }

    private func name(_ key: PreferencesKey) -> String {
        switch key {
        case .host: "regza.host"
        case .user: "regza.user"
        case .guideHost: "mirakurun.host"
        case .streamHost: "epgstation.host"
        case .ownStreamIDs: "epgstation.ownStreams"
        }
    }
}
