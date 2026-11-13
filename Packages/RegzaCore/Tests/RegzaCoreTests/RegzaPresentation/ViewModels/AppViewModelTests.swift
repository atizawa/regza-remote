import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation

/// 画面の移り変わりと Introspection
@MainActor
@Suite struct AppViewModelTests {
    let guideScreens = GuideViewModelTests()

    func makeApp(configured: Bool = true) throws -> AppViewModel {
        ViewModelFixtures().makeApp(
            connection: ConnectionData(host: configured ? "192.0.2.10" : ""), nowPlaying: nil, channels: try guideScreens.channels()
        )
    }

    @Test func opensAndClosesScreensPerTab() throws {
        let appViewModel = try makeApp()
        let channel = try #require(appViewModel.remoteViewModel.channels.first)
        appViewModel.send(.selectTab(.channels))
        appViewModel.send(.push(.channelPrograms(channelCode: channel.code)))
        let listViewModel = try #require(appViewModel.programList(channelCode: channel.code))
        // 戻る道にある間は同じ ViewModel を使う
        #expect(appViewModel.programList(channelCode: channel.code) === listViewModel)
        #expect(appViewModel.state.path(of: .channels) == [.channelPrograms(channelCode: channel.code)])
        // ほかのタブの戻る道には入らない
        #expect(appViewModel.state.path(of: .guide).isEmpty)

        appViewModel.send(.pop)
        #expect(appViewModel.state.path(of: .channels).isEmpty)
        // 閉じた画面の ViewModel は捨て、開き直すと作り直す
        #expect(appViewModel.programList(channelCode: channel.code) !== listViewModel)
    }

    /// 画面を見分ける文字列は、同じ画面なら同じで、違う画面なら違う
    @Test func routeIDsIdentifyScreens() {
        let routes: [AppRoute] = [
            .channelPrograms(channelCode: "JP-G00000001"), .channelPrograms(channelCode: "JP-G00000002"),
            .programDetail(programID: 1, channelCode: "JP-G00000001"), .programDetail(programID: 2, channelCode: "JP-G00000001"), .search,
        ]
        #expect(Set(routes.map(\.id)).count == routes.count)
        #expect(AppRoute.search.id == AppRoute.search.id)
    }

    @Test func settingsStartFromTVWhenNotConfigured() throws {
        let appViewModel = try makeApp(configured: false)
        appViewModel.send(.showSettings)
        #expect(appViewModel.state.isShowingSettings)
        // テレビが未設定なら、テレビの設定の画面から始める
        #expect(appViewModel.settingsViewModel?.state.path == [.tv])
        appViewModel.send(.closeSettings)
        #expect(!appViewModel.state.isShowingSettings)
        #expect(appViewModel.settingsViewModel == nil)
    }

    @Test func playNeedsStreamServer() throws {
        let appViewModel = try makeApp()
        let channel = try #require(appViewModel.remoteViewModel.channels.first)
        // EPGStation が設定されていないので開かない
        appViewModel.send(.play(channelCode: channel.code))
        #expect(appViewModel.state.playingChannelCode == nil)
        #expect(appViewModel.livePlayerViewModel == nil)
    }

    @Test func restoresSettingsDraftWithoutCredentialsOrRunningWork() throws {
        let original = try makeApp()
        original.send(.selectTab(.channels))
        original.send(.showSettings)
        let settings = try #require(original.settingsViewModel)
        settings.send(.setPath([.tv, .guide]))
        settings.send(.tv(.setHost("192.0.2.77")))
        settings.send(.tv(.setUser("draft-user")))
        settings.send(.tv(.setPassword("unsaved-secret")))
        settings.send(.tv(.setPIN("123456")))
        settings.send(.tv(.setShowingManualEntry(true)))
        settings.send(.server(.setHost(.guide, "guide.example:40772")))
        settings.send(.server(.setHost(.stream, "stream.example:8888")))
        let json = original.restorationJSON
        #expect(!json.contains("unsaved-secret"))
        #expect(!json.contains("123456"))

        let restored = try makeApp()
        restored.restore(json)
        let state = try #require(restored.settingsViewModel?.state)
        #expect(restored.state.tab == .channels)
        #expect(restored.state.isShowingSettings)
        #expect(state.path == [.tv, .guide])
        #expect(state.tv.host == "192.0.2.77")
        #expect(state.tv.user == "draft-user")
        #expect(state.tv.isShowingManualEntry)
        #expect(state.tv.password.isEmpty)
        #expect(state.tv.pin.isEmpty)
        #expect(!state.tv.isWaitingForPIN && !state.tv.isPairing && !state.tv.isScanning && !state.tv.isTesting)
        #expect(state.servers.guide.host == "guide.example:40772")
        #expect(state.servers.stream.host == "stream.example:8888")
        #expect(restored.livePlayerViewModel == nil)
    }

    @Test(arguments: [false, true]) func restoresSearchAndSelection(isLiteral: Bool) async throws {
        let original = try makeApp()
        original.send(.selectTab(.guide))
        original.send(.push(.search))
        let search = original.guideGridViewModel.guideSearchViewModel
        search.send(.setText("明日の夜のサッカー"))
        search.send(.removeCondition(.hours))
        if isLiteral { search.send(.searchLiterally) }
        let day = Date(timeIntervalSince1970: 1_900_000_000)
        original.guideGridViewModel.send(.selectDay(day))
        original.remoteViewModel.send(.selectBand(.bs))

        let restored = try makeApp()
        restored.restore(original.restorationJSON)
        _ = await Introspector(root: restored).waitUntilIdle()
        let state = restored.guideGridViewModel.guideSearchViewModel.state
        #expect(state.text == search.state.text)
        #expect(state.isLiteral == isLiteral)
        #expect(state.conditions == search.state.conditions)
        #expect(restored.state.path(of: .guide) == [.search])
        #expect(restored.guideGridViewModel.state.selectedDay == day)
        #expect(restored.remoteViewModel.state.selectedBand == .bs)
    }

    @Test func restoresExistingRoutesAndDropsUnavailableDetail() async throws {
        let original = try makeApp()
        let code = try #require(original.remoteViewModel.channels.first?.code)
        original.send(.selectTab(.channels))
        original.send(.push(.channelPrograms(channelCode: code)))
        original.send(.push(.programDetail(programID: -1, channelCode: code)))
        original.send(.push(.search))
        let restored = try makeApp()
        restored.restore(original.restorationJSON)
        _ = await Introspector(root: restored).waitUntilIdle()
        #expect(restored.state.path(of: .channels) == [.channelPrograms(channelCode: code)])
    }

    @Test func navigationDuringRestorationTakesPrecedence() async throws {
        let original = try makeApp()
        original.send(.push(.search))
        let restored = try makeApp()
        restored.restore(original.restorationJSON)
        restored.send(.pop)
        restored.send(.selectTab(.reservations))
        _ = await Introspector(root: restored).waitUntilIdle()
        #expect(restored.state.tab == .reservations)
        #expect(restored.state.path(of: .remote).isEmpty)
    }

    @Test func ignoresInvalidOrUnknownRestorationData() throws {
        let appViewModel = try makeApp()
        appViewModel.send(.selectTab(.channels))
        let original = appViewModel.restorationJSON
        for json in ["invalid", "{}", original.replacingOccurrences(of: "\"version\":1", with: "\"version\":2")] {
            appViewModel.restore(json)
            #expect(appViewModel.state.tab == .channels)
            #expect(appViewModel.settingsViewModel == nil)
        }
    }

    @Test func introspectionShowsStateAndActions() throws {
        let appViewModel = try makeApp()
        let introspector = Introspector(root: appViewModel)
        try introspector.perform("app", "selectTab", ["tab": .string("guide")])
        let node = try introspector.node("app")
        #expect(node.path == "app")
        guard case .object(let state) = node.state else {
            Issue.record("状態が JSON のオブジェクトになっていない: \(node.state)")
            return
        }
        #expect(state["tab"] == .string("guide"))
        #expect(state["isShowingSettings"] == .bool(false))
        #expect(node.actions.contains { $0.name == "openPrograms" })

        #expect(throws: IntrospectionError.unknownAction("fly")) { try introspector.perform("app", "fly") }
        #expect(throws: IntrospectionError.unknownPath("app/nothing")) { try introspector.node("app/nothing") }
        #expect(throws: IntrospectionError.unavailable("チャンネル none はテレビに登録されていません")) {
            try introspector.perform("app", "openPrograms", ["channel": .string("none")])
        }
    }

    @Test func reflectsValuesIntoJSON() throws {
        let channel = try #require(try guideScreens.channels().first)
        guard case .object(let object) = JSONValue(reflecting: channel) else {
            Issue.record("チャンネルが JSON のオブジェクトにならない")
            return
        }
        #expect(object["name"] == .string("テスト局１"))
        // 保存しているプロパティだけを出す (band のように計算で出すものは出さない)
        #expect(object["code"] == .string(channel.code))
        #expect(JSONValue(reflecting: AppViewModel.Route.search) == .string("search"))
        #expect(JSONValue(reflecting: Optional<Int>.none) == .null)
        #expect(JSONValue(reflecting: [1, 2]) == .array([.number(1), .number(2)]))
    }
}
