import Foundation
import Testing
@testable import RegzaPresentation
@testable import RegzaDomain
@testable import RegzaInfrastructure
@testable import RegzaApp
@testable import RegzaSample

/// 画面の移り変わりと Introspection
@MainActor
@Suite struct AppViewModelTests {
    let guideScreens = GuideViewModelTests()

    func makeApp(configured: Bool = true) throws -> AppViewModel {
        AppViewModel.sample(
            connection: RegzaConnection(host: configured ? "192.0.2.10" : ""), nowPlaying: nil, channels: try guideScreens.channels()
        )
    }

    @Test func opensAndClosesScreensPerTab() throws {
        let app = try makeApp()
        let channel = try #require(app.remote.channels.first)
        app.send(.selectTab(.channels))
        app.send(.push(.channelPrograms(channelCode: channel.code)))
        let list = try #require(app.programList(channelCode: channel.code))
        // 戻る道にある間は同じ ViewModel を使う
        #expect(app.programList(channelCode: channel.code) === list)
        #expect(app.state.path(of: .channels) == [.channelPrograms(channelCode: channel.code)])
        // ほかのタブの戻る道には入らない
        #expect(app.state.path(of: .guide).isEmpty)

        app.send(.pop)
        #expect(app.state.path(of: .channels).isEmpty)
        // 閉じた画面の ViewModel は捨て、開き直すと作り直す
        #expect(app.programList(channelCode: channel.code) !== list)
    }

    @Test func settingsStartFromTVWhenNotConfigured() throws {
        let app = try makeApp(configured: false)
        app.send(.showSettings)
        #expect(app.state.isShowingSettings)
        // テレビが未設定なら、テレビの設定の画面から始める
        #expect(app.settings?.state.path == [.tv])
        app.send(.closeSettings)
        #expect(!app.state.isShowingSettings)
        #expect(app.settings == nil)
    }

    @Test func playNeedsStreamServer() throws {
        let app = try makeApp()
        let channel = try #require(app.remote.channels.first)
        // EPGStation が設定されていないので開かない
        app.send(.play(channelCode: channel.code))
        #expect(app.state.playingChannelCode == nil)
        #expect(app.player == nil)
    }

    @Test func introspectionShowsStateAndActions() throws {
        let app = try makeApp()
        let introspector = Introspector(root: app)
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
