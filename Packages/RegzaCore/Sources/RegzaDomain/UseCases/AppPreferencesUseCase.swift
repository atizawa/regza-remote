/// アプリの表示設定。
/// @mockable
@MainActor
public protocol AppPreferencesUseCaseProtocol: AnyObject {
    var appearance: AppAppearance { get }
    func setAppearance(_ appearance: AppAppearance)
}

@MainActor
public final class AppPreferencesUseCase: AppPreferencesUseCaseProtocol {
    private let appPreferencesRepository: any AppPreferencesRepositoryProtocol

    public init(appPreferencesRepository: any AppPreferencesRepositoryProtocol) {
        self.appPreferencesRepository = appPreferencesRepository
    }

    public var appearance: AppAppearance {
        AppAppearance(rawValue: appPreferencesRepository.preferences.appearance) ?? .system
    }

    public func setAppearance(_ appearance: AppAppearance) {
        var preferences = appPreferencesRepository.preferences
        preferences.appearance = appearance.rawValue
        appPreferencesRepository.save(preferences)
    }
}
