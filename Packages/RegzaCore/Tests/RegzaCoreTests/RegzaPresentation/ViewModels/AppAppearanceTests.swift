import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

@MainActor
@Suite struct AppAppearanceTests {
    @Test(arguments: ["", "future", "system"])
    func missingOrUnknownValueUsesSystem(value: String) {
        let manager = PreferencesManager(storage: MemoryPreferencesStorage(values: [.appearance: value]))
        let useCase = AppPreferencesUseCase(appPreferencesRepository: AppPreferencesRepository(preferencesManager: manager))
        #expect(useCase.appearance == .system)
    }

    @Test func choiceIsAppliedAndSavedBeforeClosingSettings() {
        let manager = PreferencesManager(storage: MemoryPreferencesStorage(values: [.host: "192.0.2.1", .appearance: "dark"]))
        let app = makeApp(manager)
        #expect(app.state.appearance == .dark)
        app.send(.showSettings)
        let settings = app.settingsViewModel!
        #expect(settings.state.appearance == .dark)

        settings.send(.setAppearance(.light))
        #expect(app.state.appearance == .light)
        #expect(manager.value(forKey: .appearance) == "light")
        settings.send(.close)

        let restarted = makeApp(manager)
        #expect(restarted.state.appearance == .light)
        restarted.send(.showSettings)
        #expect(restarted.settingsViewModel?.state.appearance == .light)
    }

    @Test func systemChoiceIsPersistedAndStaleRestorationDoesNotOverrideIt() {
        let manager = PreferencesManager(storage: MemoryPreferencesStorage(values: [.host: "192.0.2.1", .appearance: "light"]))
        let app = makeApp(manager)
        let snapshot = app.restorationJSON
        app.send(.showSettings)
        app.settingsViewModel?.send(.setAppearance(.system))
        app.restore(snapshot)
        #expect(app.state.appearance == .system)
        #expect(makeApp(manager).state.appearance == .system)
        #expect(manager.value(forKey: .host) == "192.0.2.1")
        #expect(manager.value(forKey: .appearance) == "system")
    }

    private func makeApp(_ manager: PreferencesManager) -> AppViewModel {
        AppFactory.makeLiveAppViewModel(
            secureStorageManager: SecureStorageManager(storage: MemorySecureStorage()), preferencesManager: manager,
            transport: FakeHTTPTransport { _ in FakeHTTPTransport.response(500) })
    }
}
