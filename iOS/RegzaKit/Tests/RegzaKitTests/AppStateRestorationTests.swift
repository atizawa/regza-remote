import Foundation
import RegzaApp
import Testing

@testable import AppServices

@MainActor
@Suite struct AppStateRestorationTests {
    @Test func restoresDraftIntoNewViewModel() throws {
        let original = makeApp()
        let service = AppStateRestoration(appViewModel: original)
        service.restore("")
        original.send(.selectTab(.guide))
        original.send(.showSettings)
        let settings = try #require(original.settingsViewModel)
        settings.send(.setPath([.tv, .guide]))
        settings.send(.tv(.setHost("192.0.2.77")))
        settings.send(.tv(.setUser("draft-user")))
        settings.send(.tv(.setPassword("unsaved-secret")))
        settings.send(.tv(.setPIN("123456")))
        settings.send(.server(.setHost(.guide, "guide.example:40772")))
        original.guideGridViewModel.guideSearchViewModel.send(.setText("明日の夜のサッカー"))
        let json = try #require(service.save())
        #expect(!json.contains("unsaved-secret"))
        #expect(!json.contains("123456"))

        let restored = makeApp()
        AppStateRestoration(appViewModel: restored).restore(json)
        let state = try #require(restored.settingsViewModel?.state)
        #expect(restored.state.tab == .guide)
        #expect(state.path == [.tv, .guide])
        #expect(state.tv.host == "192.0.2.77")
        #expect(state.tv.user == "draft-user")
        #expect(state.tv.password.isEmpty)
        #expect(state.tv.pin.isEmpty)
        #expect(!state.tv.isPairing && !state.tv.isScanning)
        #expect(state.servers.guide.host == "guide.example:40772")
        #expect(restored.guideGridViewModel.guideSearchViewModel.state.text == "明日の夜のサッカー")
    }

    @Test func subsequentAppearanceDoesNotOverwriteNewInput() throws {
        let original = makeApp()
        original.send(.showSettings)
        original.settingsViewModel?.send(.tv(.setHost("192.0.2.10")))
        let saved = original.restorationJSON
        let restored = makeApp()
        let service = AppStateRestoration(appViewModel: restored)
        service.restore(saved)
        let settings = try #require(restored.settingsViewModel)
        settings.send(.tv(.setHost("192.0.2.20")))
        service.restore(saved)
        #expect(settings.state.tv.host == "192.0.2.20")

        let next = makeApp()
        AppStateRestoration(appViewModel: next).restore(try #require(service.save()))
        #expect(next.settingsViewModel?.state.tv.host == "192.0.2.20")
    }

    @Test func doesNotSaveBeforeInitialRestoration() {
        let service = AppStateRestoration(appViewModel: makeApp())
        #expect(service.save() == nil)
        service.restore("")
        #expect(service.save() != nil)
    }

    @Test func invalidDataKeepsInitialStateAndAllowsNextSave() throws {
        let restored = makeApp()
        let service = AppStateRestoration(appViewModel: restored)
        service.restore("invalid")
        #expect(restored.state.tab == .remote)
        #expect(restored.settingsViewModel == nil)
        restored.send(.selectTab(.reservations))
        let next = makeApp()
        AppStateRestoration(appViewModel: next).restore(try #require(service.save()))
        #expect(next.state.tab == .reservations)
    }

    private func makeApp() -> AppViewModel {
        AppFactory.makeLiveAppViewModel(
            secureStorageManager: SecureStorageManager(storage: MemorySecureStorage()),
            preferencesManager: PreferencesManager(storage: MemoryPreferencesStorage()),
            transport: EmptyTransport())
    }
}

private struct EmptyTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        Issue.record("復元対象の入力だけでは通信しない: \(request.url)")
        throw URLError(.cannotConnectToHost)
    }
}
