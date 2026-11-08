import Foundation
import Observation

/// アプリ全体の ViewModel (iOS と Android で共有)。画面の移り変わり (タブ・戻る道・シート・全画面) を持ち、
/// 開いている画面の ViewModel を作って持つ。どちらの OS の画面も、ここの状態を見て画面を出し、移り変わりは操作として送る
@MainActor
@Observable
public final class AppViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideUseCase
    public let recording: RecordingUseCase
    public let stream: StreamUseCase
    public let setup: SetupUseCase
    public let channels: ChannelUseCase

    // MARK: - 状態と操作

    public enum Tab: String, CaseIterable, Sendable {
        case remote, guide, channels, reservations
    }

    /// タブの中で開く画面
    public enum Route: Hashable, Sendable {
        /// 1 チャンネルの番組表
        case channelPrograms(channelCode: String)
        /// 番組の詳細 (番組の id とチャンネルのコード)。番組とチャンネルは UseCase から引く
        case programDetail(programID: Int, channelCode: String)
        /// 番組表の検索
        case search
    }

    /// 設定のシートの中で開く画面
    public enum SettingsPage: String, Hashable, Sendable {
        case tv, guide, stream
    }

    public struct State: Equatable, Sendable {
        public var tab: Tab = .remote
        /// タブごとの戻る道 (最後が手前の画面)
        public var paths: [Tab: [Route]] = [:]
        public var isShowingSettings = false
        public var settingsPath: [SettingsPage] = []
        /// いま映っているものの詳細のシート
        public var isShowingNowPlaying = false
        /// アプリで見ている局 (ライブ視聴の全画面)。ライブ視聴の中で局を切り替えたら、その局になる
        public var playingChannelCode: String?

        public func path(of tab: Tab) -> [Route] { paths[tab] ?? [] }
    }

    public enum Action: Sendable {
        case selectTab(Tab)
        /// いまのタブで画面を開く
        case open(Route)
        /// タブの戻る道をまとめて変える (iOS の戻るボタンやスワイプで戻ったとき)
        case setPath(Tab, [Route])
        /// いまのタブで 1 つ戻る
        case back
        case showSettings
        case setSettingsPath([SettingsPage])
        /// 設定を保存して閉じる
        case saveSettings
        case closeSettings
        case showNowPlaying
        case closeNowPlaying
        /// アプリで見る (ライブ視聴)
        case play(channelCode: String)
        case closePlayer
    }

    @ObservationIgnored private let work = Work()
    /// 画面の移り変わり (playingChannelCode はライブ視聴の ViewModel から求めるので、ここでは使わない)
    private var navigation = State()

    public var state: State {
        var state = navigation
        state.playingChannelCode = player?.state.channelCode
        return state
    }

    /// 画面の ViewModel は UseCase だけを使う。どの Repository の実装を使うかは、組み立てる側 (RegzaApp や見本) が決める
    public init(
        remote: RemoteViewModel, channels: ChannelUseCase, guide: GuideUseCase, recording: RecordingUseCase,
        stream: StreamUseCase, setup: SetupUseCase
    ) {
        self.channels = channels
        self.remote = remote
        self.guide = guide
        self.recording = recording
        self.stream = stream
        self.setup = setup
        channelList = ChannelListViewModel(remote: remote, channels: channels, guide: guide, stream: stream)
        guideGrid = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        nowPlaying = NowPlayingViewModel(remote: remote, guide: guide, stream: stream)
        reservationList = ReservationListViewModel(remote: remote, recording: recording)
    }

    public func send(_ action: Action) {
        // 変わったときだけ state を入れ替える (SwiftUI は戻る道などの Binding に同じ値を書き戻すことがあり、
        // そのたびに入れ替えると、変わっていないのに画面を描き直すことになる)
        var next = navigation
        defer {
            if next != navigation { navigation = next }
            forgetClosedScreens()
        }
        switch action {
        case .selectTab(let tab):
            next.tab = tab
        case .open(let route):
            next.paths[next.tab, default: []].append(route)
        case .setPath(let tab, let path):
            next.paths[tab] = path
        case .back:
            if next.paths[next.tab]?.isEmpty == false { next.paths[next.tab]?.removeLast() }
        case .showSettings:
            let remote = remote
            settings = (TVSetupViewModel(remote: remote, setup: setup), ServerSetupViewModel(setup: setup))
            // テレビが未設定なら、テレビの設定の画面から始める
            next.settingsPath = remote.connection.isConfigured ? [] : [.tv]
            next.isShowingSettings = true
        case .setSettingsPath(let path):
            next.settingsPath = path
        case .saveSettings:
            guard let settings else { return }
            work.run {
                await settings.servers.save()
                await settings.tv.save()
                self.send(.closeSettings)
            }
        case .closeSettings:
            // PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
            if let settings {
                settings.tv.send(.close)
                self.settings = nil
            }
            next.isShowingSettings = false
            next.settingsPath = []
        case .showNowPlaying:
            next.isShowingNowPlaying = true
        case .closeNowPlaying:
            next.isShowingNowPlaying = false
        case .play(let code):
            guard stream.canStream, let channel = channels.channel(code: code) else { return }
            player = LivePlayerViewModel(remote: remote, channels: channels, guide: guide, stream: stream, channel: channel)
        case .closePlayer:
            if let player {
                player.send(.end)
                self.player = nil
            }
        }
    }

    // MARK: - 開いている画面の ViewModel

    public let channelList: ChannelListViewModel
    public let guideGrid: GuideGridViewModel
    public let reservationList: ReservationListViewModel
    /// いま映っているものの詳細のシート
    public let nowPlaying: NowPlayingViewModel
    /// 設定のシートを開いている間だけある
    public private(set) var settings: (tv: TVSetupViewModel, servers: ServerSetupViewModel)?
    /// ライブ視聴を開いている間だけある
    public private(set) var player: LivePlayerViewModel?

    /// 戻る道の画面の ViewModel。戻って閉じたら捨てる (同じ画面を開き直すと読み直す)
    @ObservationIgnored private var programLists: [String: ProgramListViewModel] = [:]
    @ObservationIgnored private var programDetails: [Route: ProgramDetailViewModel] = [:]

    /// 1 チャンネルの番組表の画面の ViewModel。チャンネルがテレビに登録されていなければ nil
    public func programList(channelCode: String) -> ProgramListViewModel? {
        if let viewModel = programLists[channelCode] { return viewModel }
        guard let channel = channels.channel(code: channelCode) else { return nil }
        let viewModel = ProgramListViewModel(guide: guide, recording: recording, channel: channel)
        programLists[channelCode] = viewModel
        return viewModel
    }

    /// 番組の詳細の画面の ViewModel。番組かチャンネルが見つからなければ nil
    public func programDetail(programID: Int, channelCode: String) -> ProgramDetailViewModel? {
        let route = Route.programDetail(programID: programID, channelCode: channelCode)
        if let viewModel = programDetails[route] { return viewModel }
        guard let program = guide.program(id: programID, channelCode: channelCode),
              let channel = channels.channel(code: channelCode)
        else { return nil }
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream, program: program, channel: channel
        )
        programDetails[route] = viewModel
        return viewModel
    }

    /// どの戻る道にもない画面の ViewModel を捨てる
    private func forgetClosedScreens() {
        let open = Set(state.paths.values.flatMap { $0 })
        programLists = programLists.filter { open.contains(.channelPrograms(channelCode: $0.key)) }
        programDetails = programDetails.filter { open.contains($0.key) }
    }
}

// MARK: - Introspection

extension AppViewModel: Introspectable {
    public var introspectionName: String { "app" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }
    /// 土台・タブの画面・戻る道の画面 (`channels-0` のように、タブと奥行きで名前を付ける)
    public var introspectionChildren: [any Introspectable] {
        var children: [any Introspectable] = [remote, guideGrid, channelList, reservationList]
        if state.isShowingNowPlaying { children.append(nowPlaying) }
        if let settings { children += [settings.tv, settings.servers] }
        if let player { children.append(player) }
        for tab in Tab.allCases {
            for (depth, route) in state.path(of: tab).enumerated() {
                let screen: (any Introspectable)? = switch route {
                case .channelPrograms(let code): programList(channelCode: code)
                case .programDetail(let id, let code): programDetail(programID: id, channelCode: code)
                case .search: guideGrid.search
                }
                if let screen { children.append(IntrospectionAlias("\(tab.rawValue)-\(depth)", screen)) }
            }
        }
        return children
    }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("selectTab", "タブを選ぶ", parameters: ["tab": Tab.allCases.map(\.rawValue).joined(separator: " | ")]),
            ActionDescription("openPrograms", "いまのタブで 1 チャンネルの番組表を開く", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("openProgram", "いまのタブで番組の詳細を開く", parameters: ["channel": "チャンネルの code", "program": "番組の id"]),
            ActionDescription("openSearch", "いまのタブで番組表の検索を開く"),
            ActionDescription("back", "いまのタブで 1 つ戻る"),
            ActionDescription("showSettings", "設定を開く"),
            ActionDescription("openSettingsPage", "設定の中の画面を開く", parameters: ["page": "tv | guide | stream"]),
            ActionDescription("saveSettings", "設定を保存して閉じる"),
            ActionDescription("closeSettings", "設定を閉じる (保存しない)"),
            ActionDescription("showNowPlaying", "いま映っているものの詳細を開く"),
            ActionDescription("closeNowPlaying", "いま映っているものの詳細を閉じる"),
            ActionDescription("play", "アプリで見る (ライブ視聴)", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("closePlayer", "ライブ視聴を閉じる"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "selectTab":
            guard let tab = Tab(rawValue: try arguments.string("tab")) else { throw IntrospectionError.invalidArgument("tab") }
            send(.selectTab(tab))
        case "openPrograms":
            send(.open(.channelPrograms(channelCode: try channel(arguments).code)))
        case "openProgram":
            let channel = try channel(arguments)
            let id = try arguments.int("program")
            guard guide.program(id: id, channelCode: channel.code) != nil else {
                throw IntrospectionError.unavailable("番組 \(id) は番組表にありません")
            }
            send(.open(.programDetail(programID: id, channelCode: channel.code)))
        case "openSearch": send(.open(.search))
        case "back": send(.back)
        case "showSettings": send(.showSettings)
        case "openSettingsPage":
            guard let page = SettingsPage(rawValue: try arguments.string("page")) else { throw IntrospectionError.invalidArgument("page") }
            send(.setSettingsPath(state.settingsPath + [page]))
        case "saveSettings": send(.saveSettings)
        case "closeSettings": send(.closeSettings)
        case "showNowPlaying": send(.showNowPlaying)
        case "closeNowPlaying": send(.closeNowPlaying)
        case "play":
            send(.play(channelCode: try channel(arguments).code))
            if player == nil { throw IntrospectionError.unavailable("ライブ視聴が設定されていません") }
        case "closePlayer": send(.closePlayer)
        default: throw IntrospectionError.unknownAction(action)
        }
    }

    /// 引数 channel の code のチャンネル
    private func channel(_ arguments: [String: JSONValue]) throws -> RegzaChannel {
        let code = try arguments.string("channel")
        guard let channel = channels.channel(code: code) else {
            throw IntrospectionError.unavailable("チャンネル \(code) はテレビに登録されていません")
        }
        return channel
    }
}
