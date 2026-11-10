import Foundation
import Testing

@testable import ScreenGlueKit

@Suite struct ScreenGlueTests {
    /// Android/
    static let android = URL(filePath: #filePath).appending(path: "../../../..").standardized

    /// Git に入れたつなぎ (窓口の Swift と swift-java の設定) が、いまの State/ と Action/ から作ったものと同じ
    @Test func committedGlueIsUpToDate() throws {
        let outdated = try ScreenGlue(android: Self.android).outdatedPaths(android: Self.android)
        #expect(outdated.isEmpty, "窓口のつなぎが古くなっています: \(outdated)。Android で mise run build-swift を実行してください")
    }

    /// いまの画面は、どれも送り先と state が作られる
    @Test func everyScreenGetsSendAndState() throws {
        let glue = try ScreenGlue(android: Self.android)
        let swift = try #require(glue.files.first { $0.path == ScreenGlue.actionsPath }?.contents)
        let kotlin = try #require(glue.files.first { $0.path == ScreenGlue.kotlinPath }?.contents)
        #expect(swift.contains("public func sendChannelListAction(_ action: ChannelListAction)"))
        #expect(swift.contains("public func nextChannelListState(route: AppRoute?, after: ChannelListState?, waitID: Int64)"))
        #expect(kotlin.contains("operator fun invoke(action: ChannelListAction)"))
        #expect(kotlin.contains("fun RegzaAndroidApp.channelListStates(route: AppRoute? = null): Flow<ChannelListState?>"))
        // 部品の操作 (SettingsAction.tv の TVSetupAction) には、送る関数を作らない
        #expect(!swift.contains("sendTVSetupAction"))
    }

    // MARK: - 決まりに合わない置き方は止める

    @Test func untypedStatePropertyIsRejected() throws {
        let error = try errorFrom(files: [
            "Sample/State/SampleState.swift": "public struct SampleState {\n    public var count = 0\n}\n",
            "Sample/Action/SampleAction.swift": "public enum SampleAction {\n    case tap\n}\n",
            "Sample/SampleViewModel.swift": Self.viewModel,
        ])
        #expect(error.contains("型を書いてください"))
        #expect(error.contains("public var count = 0"))
    }

    @Test func actionWithoutViewModelIsRejected() throws {
        let error = try errorFrom(files: [
            "Sample/State/SampleState.swift": "public struct SampleState {}\n",
            "Sample/Action/SampleAction.swift": "public enum SampleAction {\n    case tap\n}\n",
            "Sample/Action/OrphanAction.swift": "public enum OrphanAction {\n    case tap\n}\n",
            "Sample/SampleViewModel.swift": Self.viewModel,
        ])
        #expect(error.contains("OrphanAction を Action にしている ViewModel"))
    }

    @Test func viewModelWithoutStateIsRejected() throws {
        let error = try errorFrom(files: [
            "Sample/Action/SampleAction.swift": "public enum SampleAction {\n    case tap\n}\n",
            "Sample/SampleViewModel.swift": "public final class SampleViewModel {\n    public typealias Action = SampleAction\n}\n",
        ])
        #expect(error.contains("public typealias State = 型"))
    }

    @Test func twoTypesInOneFileAreRejected() throws {
        let error = try errorFrom(files: [
            "Sample/State/SampleState.swift": "public struct SampleState {}\npublic struct Extra {}\n",
            "Sample/Action/SampleAction.swift": "public enum SampleAction {\n    case tap\n}\n",
            "Sample/SampleViewModel.swift": Self.viewModel,
        ])
        #expect(error.contains("1 つだけ置いてください"))
    }

    /// 部品の操作 (ほかの Action の case の値に使う型) には、送る関数を作らず、Java のクラスにだけする
    @Test func partActionGetsNoSender() throws {
        let sources = try sources(files: [
            "Sample/State/SampleState.swift": "public struct SampleState {}\n",
            "Sample/Action/SampleAction.swift": "public enum SampleAction {\n    case part(PartAction)\n}\n",
            "Sample/Action/PartAction.swift": "public enum PartAction: String {\n    case tap\n}\n",
            "Sample/SampleViewModel.swift": Self.viewModel,
        ])
        #expect(sources.screens.map(\.action) == ["SampleAction"])
        #expect(sources.presentationStubs.map(\.text).contains("public enum PartAction: String {}"))
    }

    // MARK: - 手伝い

    static let viewModel = """
        public final class SampleViewModel {
            public typealias State = SampleState
            public typealias Action = SampleAction
        }
        extension SampleViewModel: IntrospectableActions {}

        """

    /// 一時フォルダに ViewModels/ を作って読む
    func sources(files: [String: String]) throws -> Sources {
        let root = FileManager.default.temporaryDirectory.appending(path: "screen-glue-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModels = root.appending(path: "ViewModels")
        let shared = root.appending(path: "Shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        for (path, contents) in files {
            let url = viewModels.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return try Sources(viewModels: viewModels, sharedModels: shared)
    }

    /// 読んだときの説明 (読めてしまったら失敗にする)
    func errorFrom(files: [String: String]) throws -> String {
        do {
            _ = try sources(files: files)
        } catch let error as ScreenGlueError {
            return error.description
        }
        Issue.record("決まりに合わない置き方なのに、止まりませんでした")
        return ""
    }
}
