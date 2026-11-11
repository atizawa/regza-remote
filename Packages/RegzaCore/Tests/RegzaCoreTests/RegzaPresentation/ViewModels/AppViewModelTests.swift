import Foundation
import Testing

@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaPresentation
@testable import RegzaSample

/// 画面の移り変わりと Introspection
@MainActor
@Suite struct AppViewModelTests {
    let guideScreens = GuideViewModelTests()

    func makeApp(configured: Bool = true) throws -> AppViewModel {
        AppViewModel.sample(
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
