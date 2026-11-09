import Foundation
import Observation
import RegzaApp

// Android アプリに見せる窓口。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core。mise run build-swift が作り、設定は
// ../RegzaAndroid/RegzaAndroidBridge.swift-java.config)。Android 専用の部品 (Looper・BoringSSL・swift-java) に頼らないので、
// Mac の swift test で確かめられる。画面に出すものとリモコンのキー (RegzaKey) は UI の型
// (RegzaSharedModels) をそのまま渡し、Domain の型は見せない (UI の型の Java のクラスは RegzaSharedJava で作る)。
//
// 画面の状態と操作は iOS と同じ共有の ViewModel (AppViewModel とその下の画面の ViewModel) が持つ。
// ViewModel は MainActor で動き、swift-java は MainActor の同期の関数を Java に出せないので、ここに窓口を置く:
//   - snapshot() / nextSnapshot(): アプリ全体の状態 (タブ・登録の画面・接続) を返す (async なので Java の Future になる)
//   - screen() / nextScreen(): いま見えている画面の状態を返す。番組表は大きいので、全体の状態とは分け、
//     中身が変わったときだけ返す (2 秒ごとの取り直しで、番組表を渡し直さない)
//   - send(_:): 操作を送る (MainActor に順に積むだけで、すぐ返る)

// MARK: - 状態

/// アプリ全体の状態 (いま見えている画面の中身は RegzaAndroidScreen)
public struct RegzaAndroidSnapshot {
    /// 選んでいるタブ ("remote"・"guide"・"channels"・"reservations")
    public var tab: String
    /// いまのタブで戻れる (タブの中で画面を開いている)
    public var canGoBack: Bool
    /// テレビの登録の画面を出している (未登録のとき、設定を開いたとき)
    public var isShowingSetup: Bool
    /// 保存すべきテレビの接続情報 (アドレス・ユーザー名・パスワード) と番組表のアドレス。変わったら Kotlin が保存する
    public var tvHost: String
    public var tvUser: String
    public var tvPassword: String
    public var guideHost: String
    /// ライブ視聴に使う EPGStation のアドレス。変わったら Kotlin が保存する
    public var streamHost: String
    /// このアプリが頼んだ配信の ID (「1,2」のようにつなぐ)。強制終了で止められなかった配信を、次に開いたときに止めるため Kotlin が保存する
    public var ownStreamIDs: String
    public var nowPlaying: NowPlayingItem?
    /// いま見ている放送の種類 (リモコンの地デジ・BS・CS の印。チャンネル一覧から分かるときだけ)
    public var nowPlayingBand: BroadcastBand?
    /// テレビに接続できないときの説明
    public var connectionError: String?
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public var isSearchingTV: Bool
    /// 登録の画面を出している間だけある
    public var setup: RegzaAndroidSetup?
    /// ミニプレーヤーを押して開いた、いま映っているものの詳細。開いている間だけある
    public var nowPlayingDetail: RegzaAndroidNowPlaying?
    /// アプリで見ている (ライブ視聴の画面を出している) 間だけある
    public var player: LivePlayerState?
}

/// いま映っているものの詳細のシート (NowPlayingViewModel.State)
public struct RegzaAndroidNowPlaying {
    public var title: String
    /// アプリで見られる、いま映っている局
    public var playableChannelCode: String?
    public var description: String?
    public var canPowerOn: Bool
    public var canStartOver: Bool
}

/// テレビの登録と録画サーバーの設定の画面 (TVSetupViewModel.State と ServerSetupViewModel.State)
public struct RegzaAndroidSetup {
    /// 開いている設定の画面 ("tv"・"guide")。設定の最初の画面なら空
    public var page: String
    /// 設定の最初の画面に出す、テレビの状態 (「登録済み」など) と、気を付けてほしい状態か
    public var tvStatus: String
    public var tvNeedsAttention: Bool
    public var host: String
    public var user: String
    public var password: String
    public var devices: [DeviceItem]
    public var isScanning: Bool
    public var scanMessage: String?
    /// テレビに PIN が表示されていて、入力を待っている
    public var isWaitingForPIN: Bool
    public var pin: String
    public var isPairing: Bool
    public var pairingMessage: String?
    /// このアプリの ID で登録済みか
    public var isRegistered: Bool
    /// PIN で登録して保存できた (登録の画面を閉じる)
    public var hasRegistered: Bool
    /// ユーザー名とパスワードの入力欄を開いているか
    public var isShowingManualEntry: Bool
    public var isTesting: Bool
    public var testResult: String?
    /// 保存できるか
    public var canSave: Bool
    /// 登録の画面を閉じられる (登録済みのテレビがある)
    public var canClose: Bool
    /// 番組表 (Mirakurun) のアドレス
    public var guideHost: String
    /// 設定の最初の画面に出す、番組表の状態
    public var guideStatus: String
    /// 連携を解除するか確かめるときの見出しと説明
    public var guideUnlinkTitle: String
    public var guideUnlinkMessage: String
    public var guideHosts: [String]
    public var isScanningGuide: Bool
    public var guideMessage: String?
    /// 保存済みで、連携を解除できるか
    public var isGuideLinked: Bool
    /// 入力したポートが正しいか (番組表とライブ視聴の両方)
    public var isGuideHostValid: Bool
    /// Mirakurun のアドレスが入っている (EPGStation は Mirakurun から放送を受け取るので、先に番組表を設定する)
    public var hasGuideDraft: Bool
    /// ライブ視聴 (EPGStation) のアドレスと、その設定の画面に出すもの
    public var streamHost: String
    public var streamHosts: [String]
    public var isScanningStream: Bool
    public var streamMessage: String?
    public var streamStatus: String
    public var isStreamLinked: Bool
    public var streamUnlinkTitle: String
    public var streamUnlinkMessage: String
}

// MARK: - 操作

/// 画面からの操作 (共有の ViewModel の Action に送る)
public enum RegzaAndroidAction {
    case selectTab(String)
    /// いまのタブで 1 つ戻る
    case back
    // リモコン (RemoteViewModel)
    case press(RegzaKey)
    /// 録画の再生位置を変える (秒)
    case seek(Int)
    /// 画面が見えている間、2 秒ごとに取り直す
    case startPolling
    case stopPolling
    case selectBand(BroadcastBand)
    // ライブ視聴を開く・閉じる (画面の中の操作は LivePlayerAction で送る)
    /// アプリで見る (チャンネルのコード)
    case play(String)
    /// 見終わった。配信を止めてチューナーを空ける
    case closePlayer
    // いま映っているものの詳細 (NowPlayingViewModel)
    case showNowPlaying
    case closeNowPlaying
    case powerOn
    case startOver
    /// 1 チャンネルの番組表を開く (チャンネルのコード)
    case openPrograms(String)
    /// 番組の詳細を開く (チャンネルのコード、番組の id)
    case openProgram(String, Int)
    /// 番組表から検索を開く (番組表の画面の中の操作は GuideGridAction で送る)
    case openSearch
    // 番組表の検索 (GuideSearchViewModel)
    case setSearchText(String)
    /// 読み取った条件を外す (RegzaAndroidSearch.conditions の何番目か)
    case removeCondition(Int)
    case searchLiterally
    // 1 チャンネルの番組表 (ProgramListViewModel)
    case showPrograms
    case reloadPrograms
    // 番組の詳細 (ProgramDetailViewModel)
    case showDetail
    /// 録画予約する (true なら連ドラ予約)
    case reserve(Bool)
    case cancelProgramReservation
    /// 選局する (true なら放送中の番組を最初から)
    case tuneProgram(Bool)
    // 設定 (TVSetupViewModel・ServerSetupViewModel)
    case showSetup
    case closeSetup
    /// 設定の中の画面を開く ("tv"・"guide"・"stream")
    case openSetupPage(String)
    /// 設定の最初の画面に戻る
    case closeSetupPage
    case setupAppear
    case setHost(String)
    case setUser(String)
    case setPassword(String)
    case setPIN(String)
    case setShowingManualEntry(Bool)
    case scan
    case selectDevice(String)
    case startPairing
    case confirmPairing
    case cancelPairing
    case test
    case setGuideHost(String)
    case scanGuide
    case unlinkGuide
    case setStreamHost(String)
    case scanStream
    case unlinkStream
    case save
}

// MARK: - 窓口

/// アプリ全体の窓口。アプリに 1 つ作り、画面の状態を読んで操作を送る
public final class RegzaAndroidApp {
    private let store: AndroidConnectionStore
    private let app: AppViewModel
    @MainActor private let snapshotChanges = Changes()
    /// 保存先の値 (配信の ID など) が変わった回数。画面の状態とは別に変わるので、読んで見張り、変わったら Kotlin に渡し直す
    @MainActor private let storeRevision = StoreRevision()
    @MainActor private let screenChanges = Changes()
    /// 前に返した画面の状態 (同じなら返さない)
    @MainActor private var lastScreen: ScreenKey?

    /// 保存してある値から作る。メインスレッドから呼ぶ (先に regzaSetUpMainActor を呼んでおく)
    public convenience init(
        host: String, user: String, password: String, pairingUserID: String, guideHost: String, streamHost: String, ownStreamIDs: String
    ) {
        let store = AndroidConnectionStore(
            connection: RegzaConnection(host: host, user: user, password: password),
            pairingUserID: pairingUserID,
            guideHost: guideHost,
            streamHost: streamHost,
            ownStreamIDs: ownStreamIDs.split(separator: ",").compactMap { Int($0) }
        )
        self.init(app: MainActor.assumeIsolated { AppViewModel(store: store) }, store: store)
    }

    /// 組み立てた ViewModel と保存先から作る (テストでは、テレビにつながない見本の ViewModel を渡す)
    init(app: AppViewModel, store: AndroidConnectionStore) {
        self.store = store
        self.app = app
        MainActor.assumeIsolated {
            // 未登録なら、テレビの登録の画面から始める
            if !app.remote.state.isConfigured { app.send(.showSettings) }
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            Task { await app.cleanUpStreams() }
        }
        // 配信を止めて ID を消したときなどは、画面の状態が変わったあとに保存先だけが変わるので、別に知らせる
        let storeRevision = MainActor.assumeIsolated { self.storeRevision }
        store.onChange = { Task { @MainActor in storeRevision.value += 1 } }
    }

    /// いまのアプリ全体の状態
    public func snapshot() async -> RegzaAndroidSnapshot {
        await currentSnapshot()
    }

    /// 前に返したときからアプリ全体の状態が変わるまで待って、変わった状態を返す
    public func nextSnapshot() async -> RegzaAndroidSnapshot {
        await snapshotChanges.wait()
        return await snapshot()
    }

    /// いま見えている画面の状態
    public func screen() async -> RegzaAndroidScreen {
        await currentScreen()
    }

    /// 見えている画面の状態が前に返したものから変わるまで待って、変わった状態を返す
    public func nextScreen() async -> RegzaAndroidScreen {
        await nextScreenOnMain()
    }

    /// 操作を送る。送った順に MainActor で処理する
    public func send(_ action: RegzaAndroidAction) {
        Task { @MainActor in self.perform(action) }
    }

    // MARK: ViewModel の state から作る

    @MainActor private func currentSnapshot() -> RegzaAndroidSnapshot {
        snapshotChanges.track { makeSnapshot() }
    }

    @MainActor private func currentScreen() -> RegzaAndroidScreen {
        makeScreen(screenChanges.track { screenKey() })
    }

    @MainActor private func makeSnapshot() -> RegzaAndroidSnapshot {
        let appState = app.state
        let remote = app.remote.state
        let settings = appState.isShowingSettings ? app.settings : nil
        let nowPlaying = appState.isShowingNowPlaying ? app.nowPlaying.state : nil
        _ = storeRevision.value
        // 保存する値は、ViewModel ではなく保存先から読む (Android では Kotlin が保存するので、保存先の値を渡す)
        let connection = store.load()
        return RegzaAndroidSnapshot(
            tab: appState.tab.rawValue,
            canGoBack: !appState.path(of: appState.tab).isEmpty,
            isShowingSetup: settings != nil,
            tvHost: connection.host,
            tvUser: connection.user,
            tvPassword: connection.password,
            guideHost: store.guideHost,
            streamHost: store.streamHost,
            ownStreamIDs: store.ownStreamIDs.map(String.init).joined(separator: ","),
            nowPlaying: remote.nowPlaying,
            nowPlayingBand: remote.nowPlayingBand,
            connectionError: remote.errorMessage,
            isSearchingTV: remote.isSearchingTV,
            setup: settings.map { settings in
                let tv = settings.tv.state
                let servers = settings.servers.state
                return RegzaAndroidSetup(
                    page: appState.settingsPath.last?.rawValue ?? "",
                    tvStatus: tv.status.text,
                    tvNeedsAttention: tv.status.needsAttention,
                    host: tv.host,
                    user: tv.user,
                    password: tv.password,
                    devices: tv.devices,
                    isScanning: tv.isScanning,
                    scanMessage: tv.scanMessage,
                    isWaitingForPIN: tv.isWaitingForPIN,
                    pin: tv.pin,
                    isPairing: tv.isPairing,
                    pairingMessage: tv.pairingMessage,
                    isRegistered: tv.isRegistered,
                    hasRegistered: tv.hasRegistered,
                    isShowingManualEntry: tv.isShowingManualEntry,
                    isTesting: tv.isTesting,
                    testResult: tv.testResult,
                    canSave: tv.canSave && servers.isValid,
                    canClose: remote.isConfigured,
                    guideHost: servers.guide.host,
                    guideStatus: servers.guide.status,
                    guideUnlinkTitle: servers.guide.unlinkTitle,
                    guideUnlinkMessage: servers.guide.unlinkMessage,
                    guideHosts: servers.guide.hosts,
                    isScanningGuide: servers.guide.isScanning,
                    guideMessage: servers.guide.message,
                    isGuideLinked: servers.guide.isLinked,
                    isGuideHostValid: servers.isValid,
                    hasGuideDraft: servers.hasGuideDraft,
                    streamHost: servers.stream.host,
                    streamHosts: servers.stream.hosts,
                    isScanningStream: servers.stream.isScanning,
                    streamMessage: servers.stream.message,
                    streamStatus: servers.stream.status,
                    isStreamLinked: servers.stream.isLinked,
                    streamUnlinkTitle: servers.stream.unlinkTitle,
                    streamUnlinkMessage: servers.stream.unlinkMessage
                )
            },
            nowPlayingDetail: nowPlaying.map {
                RegzaAndroidNowPlaying(
                    title: $0.title, playableChannelCode: $0.playableChannelCode, description: $0.description,
                    canPowerOn: $0.canPowerOn, canStartOver: $0.canStartOver
                )
            },
            player: app.player?.state
        )
    }

    /// いま見えている画面 (いまのタブの戻る道の最後、なければタブの最初の画面) の state
    @MainActor private func screenKey() -> ScreenKey {
        let state = app.state
        switch state.path(of: state.tab).last {
        case .channelPrograms(let code):
            // チャンネルが見つからなければ、タブの最初の画面を出す
            if let list = app.programList(channelCode: code) { return .programs(list.state) }
        case .programDetail(let id, let code):
            // 番組が見つからなければ、タブの最初の画面を出す
            if let detail = app.programDetail(programID: id, channelCode: code) { return .detail(detail.state) }
        case .search: return .search(app.guideGrid.search.state)
        case nil: break
        }
        switch state.tab {
        case .remote: return .remote
        case .channels: return .channels(app.channelList.state)
        case .reservations: return .reservations(app.reservationList.state)
        case .guide: return .guide(app.guideGrid.state)
        }
    }

    @MainActor private func makeScreen(_ key: ScreenKey) -> RegzaAndroidScreen {
        lastScreen = key
        return RegzaAndroidScreen(key)
    }

    @MainActor private func nextScreenOnMain() async -> RegzaAndroidScreen {
        while true {
            await screenChanges.wait()
            let key = screenChanges.track { screenKey() }
            if key != lastScreen { return makeScreen(key) }
        }
    }

    // MARK: 操作

    /// 操作を ViewModel の操作に置き換えて送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: RegzaAndroidAction) {
        let tv = app.settings?.tv
        let servers = app.settings?.servers
        switch action {
        case .selectTab(let tab):
            if let tab = AppViewModel.Tab(rawValue: tab) { app.send(.selectTab(tab)) }
        case .back: app.send(.back)
        case .press(let key): app.remote.send(.press(key))
        case .seek(let position): app.remote.send(.seek(position))
        case .startPolling: app.remote.send(.startPolling)
        case .stopPolling: app.remote.send(.stopPolling)
        case .selectBand(let band): app.remote.send(.selectBand(band))
        case .play(let code): app.send(.play(channelCode: code))
        case .closePlayer: app.send(.closePlayer)
        case .showNowPlaying:
            app.send(.showNowPlaying)
            app.nowPlaying.send(.appear)
        case .closeNowPlaying: app.send(.closeNowPlaying)
        case .powerOn: app.nowPlaying.send(.powerOn)
        case .startOver: app.nowPlaying.send(.startOver)
        case .openPrograms(let code):
            app.send(.open(.channelPrograms(channelCode: code)))
        case .openProgram(let code, let id): app.send(.open(.programDetail(programID: id, channelCode: code)))
        case .openSearch: app.send(.open(.search))
        case .setSearchText(let text): app.guideGrid.search.send(.setText(text))
        case .removeCondition(let index):
            let conditions = app.guideGrid.search.state.conditions
            if conditions.indices.contains(index) { app.guideGrid.search.send(.removeCondition(conditions[index].condition)) }
        case .searchLiterally: app.guideGrid.search.send(.searchLiterally)
        case .showPrograms: currentProgramList()?.send(.appear)
        case .reloadPrograms: currentProgramList()?.send(.reload)
        case .showDetail: currentDetail()?.send(.appear)
        case .reserve(let series): currentDetail()?.send(.reserve(series: series))
        case .cancelProgramReservation: currentDetail()?.send(.cancelReservation)
        case .tuneProgram(let startOver): currentDetail()?.send(.tune(startOver: startOver))
        case .showSetup: app.send(.showSettings)
        case .closeSetup: app.send(.closeSettings)
        case .openSetupPage(let page):
            guard let page = AppViewModel.SettingsPage(rawValue: page) else { return }
            app.send(.setSettingsPath([page]))
            // Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
            if page == .stream { servers?.send(.suggestStreamHost) }
        case .closeSetupPage: app.send(.setSettingsPath([]))
        case .setupAppear: tv?.send(.appear)
        case .setHost(let host): tv?.send(.setHost(host))
        case .setUser(let user): tv?.send(.setUser(user))
        case .setPassword(let password): tv?.send(.setPassword(password))
        case .setPIN(let pin): tv?.send(.setPIN(pin))
        case .setShowingManualEntry(let isShowing): tv?.send(.setShowingManualEntry(isShowing))
        case .scan: tv?.send(.scan)
        case .selectDevice(let host): tv?.send(.select(host))
        case .startPairing: tv?.send(.startPairing)
        case .confirmPairing: tv?.send(.confirmPairing)
        case .cancelPairing: tv?.send(.cancelPairing)
        case .test: tv?.send(.test)
        case .setGuideHost(let host): servers?.send(.setHost(.guide, host))
        case .scanGuide: servers?.send(.scan(.guide))
        case .unlinkGuide: servers?.send(.unlink(.guide))
        case .setStreamHost(let host): servers?.send(.setHost(.stream, host))
        case .scanStream: servers?.send(.scan(.stream))
        case .unlinkStream: servers?.send(.unlink(.stream))
        case .save: app.send(.saveSettings)
        }
    }

    /// 画面ごとの操作 (ChannelListAction など) を、開いている画面の ViewModel に手前から渡してみて、受け取ったところで止める。
    /// 画面ごとの send と perform は、scripts/generate-screen-glue.sh が Generated/ScreenActions.swift に作る
    @MainActor func route(_ deliver: (AnyObject) -> Bool) {
        for viewModel in app.openViewModels {
            if deliver(viewModel) { return }
        }
    }

    @MainActor private func currentProgramList() -> ProgramListViewModel? {
        guard case .channelPrograms(let code) = app.state.path(of: app.state.tab).last else { return nil }
        return app.programList(channelCode: code)
    }

    @MainActor private func currentDetail() -> ProgramDetailViewModel? {
        guard case .programDetail(let id, let code) = app.state.path(of: app.state.tab).last else { return nil }
        return app.programDetail(programID: id, channelCode: code)
    }
}

/// 保存先の値が変わった回数 (見張るためだけに使う)
@MainActor
@Observable
private final class StoreRevision {
    var value = 0
}

/// 状態の変わり目を知らせる。読んだ値を見張り、変わったら待っている側を起こす
/// (待ち始める前に変わっていても逃さない)
@MainActor
private final class Changes {
    private var hasChanged = false
    private var waiter: CheckedContinuation<Void, Never>?

    /// 値を作り、その中で読んだものを見張る
    func track<Value>(_ make: () -> Value) -> Value {
        hasChanged = false
        return withObservationTracking(make) { [weak self] in
            // 変わる直前に呼ばれるので、変わり終わってから知らせる
            Task { @MainActor in self?.changed() }
        }
    }

    func wait() async {
        if hasChanged { return }
        await withCheckedContinuation { waiter = $0 }
    }

    private func changed() {
        hasChanged = true
        waiter?.resume()
        waiter = nil
    }
}

/// Android の保存先。値は Kotlin が保存しているものを起動時に受け取り、
/// 変わった接続情報・録画サーバーのアドレス・配信の ID は RegzaAndroidSnapshot から Kotlin が保存する
final class AndroidConnectionStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private let userID: String
    private var values: (guideHost: String, streamHost: String, ownStreamIDs: [Int])
    /// 録画サーバーのアドレスや配信の ID が変わったら呼ぶ (Kotlin に保存し直してもらう)
    var onChange: @Sendable () -> Void = {}

    init(connection: RegzaConnection, pairingUserID: String, guideHost: String, streamHost: String, ownStreamIDs: [Int]) {
        self.connection = connection
        userID = pairingUserID
        values = (guideHost, streamHost, ownStreamIDs)
    }

    func load() -> RegzaConnection { lock.withLock { connection } }
    func save(_ connection: RegzaConnection) {
        lock.withLock { self.connection = connection }
        onChange()
    }
    func pairingUserID() -> String { userID }

    var guideHost: String {
        get { lock.withLock { values.guideHost } }
        set {
            lock.withLock { values.guideHost = newValue }
            onChange()
        }
    }

    var streamHost: String {
        get { lock.withLock { values.streamHost } }
        set {
            lock.withLock { values.streamHost = newValue }
            onChange()
        }
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { values.ownStreamIDs } }
        set {
            lock.withLock { values.ownStreamIDs = newValue }
            onChange()
        }
    }
}
