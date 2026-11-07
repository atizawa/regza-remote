import Foundation
import Observation

/// アプリ全体の ViewModel (iOS と Android で共有)。画面の移り変わり (タブ・戻る道・シート・全画面) を持ち、
/// 開いている画面の ViewModel を作って持つ。どちらの OS の画面も、ここの状態を見て画面を出し、移り変わりは操作として送る
@MainActor
@Observable
public final class AppViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel
    public let recording: ReservationsViewModel
    public let stream: StreamViewModel

    // MARK: - 状態と操作

    public enum Tab: String, CaseIterable, Sendable {
        case remote, guide, channels, reservations
    }

    /// タブの中で開く画面
    public enum Route: Hashable, Sendable {
        /// 1 チャンネルの番組表
        case channelPrograms(RegzaChannel)
        case programDetail(MirakurunProgram, RegzaChannel)
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
        /// アプリで見ている局 (ライブ視聴の全画面)
        public var playingChannel: RegzaChannel?

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
        case closeSettings
        case showNowPlaying
        case closeNowPlaying
        /// アプリで見る (ライブ視聴)
        case play(RegzaChannel)
        case closePlayer
    }

    public private(set) var state = State()

    public init(remote: RemoteViewModel, guide: GuideViewModel, recording: ReservationsViewModel, stream: StreamViewModel) {
        self.remote = remote
        self.guide = guide
        self.recording = recording
        self.stream = stream
        channelList = ChannelListViewModel(remote: remote, guide: guide, stream: stream)
        guideGrid = GuideGridViewModel(remote: remote, guide: guide, recording: recording)
        reservationList = ReservationListViewModel(remote: remote, recording: recording)
    }

    /// 保存先とリモコンから、アプリ全体の ViewModel をまとめて作る
    public convenience init(store: any RegzaConnectionStore, remote: RegzaRemote? = nil) {
        let model = RemoteViewModel(store: store, remote: remote)
        let guide = GuideViewModel(remote: model)
        self.init(remote: model, guide: guide, recording: ReservationsViewModel(remote: model), stream: StreamViewModel(remote: model, guide: guide))
    }

    public func send(_ action: Action) {
        // 変わったときだけ state を入れ替える (SwiftUI は戻る道などの Binding に同じ値を書き戻すことがあり、
        // そのたびに入れ替えると、変わっていないのに画面を描き直すことになる)
        var next = state
        defer {
            if next != state { state = next }
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
            settings = (TVSetupViewModel(remote: remote), ServerSetupViewModel(guide: guide, stream: stream))
            // テレビが未設定なら、テレビの設定の画面から始める
            next.settingsPath = remote.connection.isConfigured ? [] : [.tv]
            next.isShowingSettings = true
        case .setSettingsPath(let path):
            next.settingsPath = path
        case .closeSettings:
            // PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
            if let settings {
                settings.tv.close()
                self.settings = nil
            }
            next.isShowingSettings = false
            next.settingsPath = []
        case .showNowPlaying:
            next.isShowingNowPlaying = true
        case .closeNowPlaying:
            next.isShowingNowPlaying = false
        case .play(let channel):
            guard let viewModel = stream.livePlayer(for: channel) else { return }
            player = viewModel
            next.playingChannel = channel
        case .closePlayer:
            if let player {
                player.end()
                self.player = nil
            }
            next.playingChannel = nil
        }
    }

    // MARK: - 開いている画面の ViewModel

    public let channelList: ChannelListViewModel
    public let guideGrid: GuideGridViewModel
    public let reservationList: ReservationListViewModel
    /// 設定のシートを開いている間だけある
    public private(set) var settings: (tv: TVSetupViewModel, servers: ServerSetupViewModel)?
    /// ライブ視聴を開いている間だけある
    public private(set) var player: LivePlayerViewModel?

    /// 戻る道の画面の ViewModel。戻って閉じたら捨てる (同じ画面を開き直すと読み直す)
    @ObservationIgnored private var programLists: [RegzaChannel: ProgramListViewModel] = [:]
    @ObservationIgnored private var programDetails: [Route: ProgramDetailViewModel] = [:]

    public func programList(for channel: RegzaChannel) -> ProgramListViewModel {
        if let viewModel = programLists[channel] { return viewModel }
        let viewModel = ProgramListViewModel(guide: guide, recording: recording, channel: channel)
        programLists[channel] = viewModel
        return viewModel
    }

    public func programDetail(_ program: MirakurunProgram, channel: RegzaChannel) -> ProgramDetailViewModel {
        let route = Route.programDetail(program, channel)
        if let viewModel = programDetails[route] { return viewModel }
        let viewModel = ProgramDetailViewModel(
            remote: remote, guide: guide, recording: recording, stream: stream, program: program, channel: channel
        )
        programDetails[route] = viewModel
        return viewModel
    }

    /// どの戻る道にもない画面の ViewModel を捨てる
    private func forgetClosedScreens() {
        let open = Set(state.paths.values.flatMap { $0 })
        programLists = programLists.filter { open.contains(.channelPrograms($0.key)) }
        programDetails = programDetails.filter { open.contains($0.key) }
    }
}

// MARK: - Introspection

extension AppViewModel: Introspectable {
    public var introspectionName: String { "app" }
    public var introspectionValue: Any { state }
    /// 土台・タブの画面・戻る道の画面 (`channels-0` のように、タブと奥行きで名前を付ける)
    public var introspectionChildren: [any Introspectable] {
        var children: [any Introspectable] = [remote, guideGrid, channelList, reservationList]
        for tab in Tab.allCases {
            for (depth, route) in state.path(of: tab).enumerated() {
                let screen: any Introspectable = switch route {
                case .channelPrograms(let channel): programList(for: channel)
                case .programDetail(let program, let channel): programDetail(program, channel: channel)
                case .search: guideGrid.search
                }
                children.append(IntrospectionAlias("\(tab.rawValue)-\(depth)", screen))
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
            ActionDescription("closeSettings", "設定を閉じる"),
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
            send(.open(.channelPrograms(try channel(arguments))))
        case "openProgram":
            let channel = try channel(arguments)
            let id = try arguments.int("program")
            guard let program = guide.guidePrograms[channel.code]?.first(where: { $0.id == id }) else {
                throw IntrospectionError.unavailable("番組 \(id) は番組表にありません")
            }
            send(.open(.programDetail(program, channel)))
        case "openSearch": send(.open(.search))
        case "back": send(.back)
        case "showSettings": send(.showSettings)
        case "openSettingsPage":
            guard let page = SettingsPage(rawValue: try arguments.string("page")) else { throw IntrospectionError.invalidArgument("page") }
            send(.setSettingsPath(state.settingsPath + [page]))
        case "closeSettings": send(.closeSettings)
        case "showNowPlaying": send(.showNowPlaying)
        case "closeNowPlaying": send(.closeNowPlaying)
        case "play":
            let channel = try channel(arguments)
            send(.play(channel))
            if player == nil { throw IntrospectionError.unavailable("ライブ視聴が設定されていません") }
        case "closePlayer": send(.closePlayer)
        default: throw IntrospectionError.unknownAction(action)
        }
    }

    /// 引数 channel の code のチャンネル
    private func channel(_ arguments: [String: JSONValue]) throws -> RegzaChannel {
        let code = try arguments.string("channel")
        guard let channel = remote.channels.first(where: { $0.code == code }) else {
            throw IntrospectionError.unavailable("チャンネル \(code) はテレビに登録されていません")
        }
        return channel
    }
}
