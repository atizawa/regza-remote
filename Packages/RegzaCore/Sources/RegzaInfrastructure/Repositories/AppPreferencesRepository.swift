import RegzaDomain

@MainActor
public final class AppPreferencesRepository: AppPreferencesRepositoryProtocol {
    private let preferencesManager: PreferencesManager

    public init(preferencesManager: PreferencesManager) { self.preferencesManager = preferencesManager }

    public var preferences: AppPreferencesData {
        AppPreferencesData(appearance: preferencesManager.value(forKey: .appearance) ?? "system")
    }

    public func save(_ preferences: AppPreferencesData) {
        preferencesManager.setValue(preferences.appearance, forKey: .appearance)
    }
}
