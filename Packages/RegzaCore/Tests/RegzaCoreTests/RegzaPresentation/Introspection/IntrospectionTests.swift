import Foundation
import Testing

@testable import AppPresentation
@testable import ChannelsPresentation
@testable import GuidePresentation
@testable import PlayerPresentation
@testable import PresentationCore
@testable import ProgramPresentation
@testable import RegzaApp
@testable import RegzaDomain
@testable import RegzaFakeServers
@testable import RegzaInfrastructure
@testable import ReservationsPresentation
@testable import SettingsPresentation

/// ViewModel を外から読み、操作する口 (Introspection)
@MainActor
@Suite struct IntrospectionTests {
    @Test func introspectionReachesScreensOnPath() async throws {
        let appViewModel = HTTPTestEnvironment(
            transport: FakeHTTPTransport { request in
                request.url.path.hasSuffix("channel_list")
                    ? FakeHTTPTransport.response(200, TestData.channelListJSON) : FakeHTTPTransport.response(500)
            }
        ).appViewModel
        let introspector = Introspector(root: appViewModel)
        try introspector.perform("app/channelList", "reload")
        _ = await introspector.waitUntilIdle()
        try introspector.perform("app", "selectTab", ["tab": .string("channels")])
        try introspector.perform("app", "openPrograms", ["channel": .string("JP-G00000002")])
        #expect(introspector.paths().contains("app/channels-0"))
        #expect(try introspector.node("app/channels-0").actions.map(\.name) == ["appear", "reload"])
    }

    /// どの画面も開き、どの ViewModel の操作の名前も重ならないこと (重なると後ろの操作を送れない)。
    /// 部品の表を親の表に入れたときの重なりも、ここで見る
    @Test func actionNamesAreUniqueOnEveryScreen() async throws {
        let appViewModel = FakeApp.makeAppViewModel()
        let introspector = Introspector(root: appViewModel)
        try introspector.perform("app", "prepareRoutes")
        _ = await introspector.waitUntilIdle()
        let column = try #require(appViewModel.guideGridViewModel.state.columns.first { !$0.programs.isEmpty })
        let program = try #require(column.programs.first)
        try introspector.perform("app", "selectTab", ["tab": .string("guide")])
        try introspector.perform("app", "openPrograms", ["channel": .string(column.channelCode)])
        try introspector.perform("app", "openProgram", ["channel": .string(column.channelCode), "program": .number(Double(program.id))])
        try introspector.perform("app", "openSearch")
        try introspector.perform("app", "showSettings")
        try introspector.perform("app", "showNowPlaying")
        try introspector.perform("app", "play", ["channel": .string(column.channelCode)])
        let nodes = try introspector.paths().map(introspector.node)
        // アプリ全体・リモコン・各タブの最初の画面・番組表の検索・開いた画面 (番組の一覧・詳細・設定・いま映っているもの・ライブ視聴)
        #expect(nodes.count >= 12, "\(nodes.map(\.path))")
        for node in nodes {
            let names = node.actions.map(\.name)
            #expect(Set(names).count == names.count, "\(node.path) の操作の名前が重なっています")
        }
    }

    /// 操作の一覧は表から作るので、受け付ける名前と引数がそのまま見える
    @Test func actionsComeFromTheTable() async throws {
        let appViewModel = HTTPTestEnvironment(transport: FakeHTTPTransport { _ in FakeHTTPTransport.response(500) }).appViewModel
        let introspector = Introspector(root: appViewModel)
        try introspector.perform("app", "showSettings")
        let nodes = try introspector.paths().map(introspector.node)
        // 部品の操作は、名前の前に部品の名前を付けて見せる
        let settings = try #require(nodes.first { $0.name == "settings" })
        #expect(settings.actions.first { $0.name == "tv.setPIN" }?.parameters == ["pin": "PIN"])
        // 引数は、一覧に書いた名前で読む
        #expect(throws: IntrospectionError.missingArgument("key")) { try introspector.perform("app/remote", "press") }
        #expect(throws: IntrospectionError.invalidArgument("key")) {
            try introspector.perform("app/remote", "press", ["key": .string("none")])
        }
        #expect(throws: IntrospectionError.unknownAction("none")) { try introspector.perform("app/remote", "none") }
        // 省いてよい引数は、null も省いたものとして扱う
        #expect(throws: Never.self) { try introspector.perform("app/remote", "selectBand", ["band": .null]) }
        // 並びの引数は、省くと空。null や並びでない値は受け付けない
        #expect(throws: IntrospectionError.invalidArgument("path")) {
            try introspector.perform("app", "setPath", ["tab": .string("channels"), "path": .null])
        }
    }
}
