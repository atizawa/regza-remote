public import Foundation
public import Observation
package import RegzaDomain

/// アプリ全体の ViewModel。画面の移り変わり (タブ・戻る道・シート・全画面) を持ち、
/// 開いている画面の ViewModel を作って持つ。どちらの OS の画面も、ここの状態を見て画面を出し、移り変わりは操作として送る
@MainActor
@Observable
public final class AppViewModel {
    public let remote: RemoteViewModel
    package let guide: any GuideUseCaseProtocol
    package let recording: any RecordingUseCaseProtocol
    package let stream: any StreamUseCaseProtocol
    package let setup: any SetupUseCaseProtocol
    package let channels: any ChannelUseCaseProtocol

    // MARK: - 状態と操作

    /// タブ
    public typealias Tab = AppTab

    /// タブの中で開く画面
    public typealias Route = AppRoute

    /// 画面に出すもの
    public typealias State = AppState

    /// 画面からの操作
    public typealias Action = AppAction

    @ObservationIgnored private let work = Work()
    /// 画面の移り変わり (playingChannelCode はライブ視聴の ViewModel から求めるので、ここでは使わない)
    private var navigation = State()

    public var state: State {
        var state = navigation
        state.playingChannelCode = player?.state.channelCode
        return state
    }

    /// 画面の ViewModel は UseCase だけを使う。どの Repository の実装を使うかは、組み立てる側 (RegzaApp や見本) が決める
    package init(
        remote: RemoteViewModel, channels: any ChannelUseCaseProtocol, guide: any GuideUseCaseProtocol,
        recording: any RecordingUseCaseProtocol,
        stream: any StreamUseCaseProtocol, setup: any SetupUseCaseProtocol
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
        case .push(let route):
            next.paths[next.tab, default: []].append(route)
        case .setPath(let tab, let path):
            next.paths[tab] = path
        case .pop:
            if next.paths[next.tab]?.isEmpty == false { next.paths[next.tab]?.removeLast() }
        case .showSettings:
            settings = SettingsViewModel(remote: remote, setup: setup) { [weak self] in self?.send(.closeSettings) }
            next.isShowingSettings = true
        case .closeSettings:
            if let settings {
                settings.dismiss()
                self.settings = nil
            }
            next.isShowingSettings = false
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
    public private(set) var settings: SettingsViewModel?
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

    /// path の画面の ViewModel。チャンネルや番組が見つからなければ nil
    public func viewModel(for route: Route) -> AnyObject? {
        switch route {
        case .channelPrograms(let code): programList(channelCode: code)
        case .programDetail(let id, let code): programDetail(programID: id, channelCode: code)
        case .search: guideGrid.search
        }
    }

    /// いま開いている画面の ViewModel を手前から並べる。操作の型から送り先を選ぶときに使う
    /// (同じ種類の画面が別のタブにも開いていれば、いまのタブの手前のものが先に来る)
    public var openViewModels: [AnyObject] {
        var result: [AnyObject] = []
        if let player { result.append(player) }
        if let settings { result.append(settings) }
        if state.isShowingNowPlaying { result.append(nowPlaying) }
        let tabs = [state.tab] + Tab.allCases.filter { $0 != state.tab }
        for tab in tabs {
            result += state.path(of: tab).reversed().compactMap(viewModel(for:))
        }
        // 番組表の検索は、開く前から番組表と一緒にある (CLI からも見える)
        result += [channelList, guideGrid, guideGrid.search, reservationList, remote]
        return result
    }

    /// 前回、強制終了などで止められずに残ったライブ視聴の配信を止める (アプリを開いたときに呼ぶ)
    public func cleanUpStreams() async {
        await stream.cleanUp()
    }

    /// どの戻る道にもない画面の ViewModel を捨てる
    private func forgetClosedScreens() {
        let open = Set(state.paths.values.flatMap { $0 })
        programLists = programLists.filter { open.contains(.channelPrograms(channelCode: $0.key)) }
        programDetails = programDetails.filter { open.contains($0.key) }
    }
}

// MARK: - Introspection

extension AppViewModel: IntrospectableActions {
    public var introspectionName: String { "app" }
    public var isBusy: Bool { work.isBusy }
    /// 土台・タブの画面・戻る道の画面 (`channels-0` のように、タブと奥行きで名前を付ける)
    public var introspectionChildren: [any Introspectable] {
        var children: [any Introspectable] = [remote, guideGrid, channelList, reservationList]
        if state.isShowingNowPlaying { children.append(nowPlaying) }
        if let settings { children.append(settings) }
        if let player { children.append(player) }
        for tab in Tab.allCases {
            for (depth, route) in state.path(of: tab).enumerated() {
                let screen: (any Introspectable)? =
                    switch route {
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
            ActionDescription(
                "setPath", "タブの path をまとめて変える (iOS で戻るスワイプをしたときと同じ)",
                parameters: ["tab": Tab.allCases.map(\.rawValue).joined(separator: " | "), "path": "ls の paths と同じ形の画面の並び"]
            ),
            ActionDescription("showSettings", "設定を開く"),
            ActionDescription("closeSettings", "設定を閉じる (保存しない)"),
            ActionDescription("showNowPlaying", "いま映っているものの詳細を開く"),
            ActionDescription("closeNowPlaying", "いま映っているものの詳細を閉じる"),
            ActionDescription("play", "アプリで見る (ライブ視聴)", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("closePlayer", "ライブ視聴を閉じる"),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "selectTab":
            guard let tab = Tab(rawValue: try arguments.string("tab")) else { throw IntrospectionError.invalidArgument("tab") }
            return .selectTab(tab)
        case "openPrograms":
            return .push(.channelPrograms(channelCode: try channel(arguments).code))
        case "openProgram":
            let channel = try channel(arguments)
            let id = try arguments.int("program")
            guard guide.program(id: id, channelCode: channel.code) != nil else {
                throw IntrospectionError.unavailable("番組 \(id) は番組表にありません")
            }
            return .push(.programDetail(programID: id, channelCode: channel.code))
        case "openSearch": return .push(.search)
        case "back": return .pop
        case "setPath":
            guard let tab = Tab(rawValue: try arguments.string("tab")) else { throw IntrospectionError.invalidArgument("tab") }
            guard case .array(let routes) = arguments["path"] ?? .array([]) else { throw IntrospectionError.invalidArgument("path") }
            return .setPath(tab, try routes.map(Self.route))
        case "showSettings": return .showSettings
        case "closeSettings": return .closeSettings
        case "showNowPlaying": return .showNowPlaying
        case "closeNowPlaying": return .closeNowPlaying
        case "play":
            let channel = try channel(arguments)
            guard stream.canStream else { throw IntrospectionError.unavailable("ライブ視聴が設定されていません") }
            return .play(channelCode: channel.code)
        case "closePlayer": return .closePlayer
        default: throw IntrospectionError.unknownAction(name)
        }
    }

    /// ls の paths と同じ形の画面 ({"channelPrograms": {"channelCode": …}} や "search")
    private static func route(_ value: JSONValue) throws -> Route {
        switch value {
        case .string("search"): return .search
        case .object(let object):
            if case .object(let values)? = object["channelPrograms"] {
                return .channelPrograms(channelCode: try values.string("channelCode"))
            }
            if case .object(let values)? = object["programDetail"] {
                return .programDetail(programID: try values.int("programID"), channelCode: try values.string("channelCode"))
            }
        default: break
        }
        throw IntrospectionError.invalidArgument("path")
    }

    /// 引数 channel の code のチャンネル
    private func channel(_ arguments: [String: JSONValue]) throws -> ChannelItem {
        let code = try arguments.string("channel")
        guard let channel = channels.channel(code: code) else {
            throw IntrospectionError.unavailable("チャンネル \(code) はテレビに登録されていません")
        }
        return channel
    }
}
