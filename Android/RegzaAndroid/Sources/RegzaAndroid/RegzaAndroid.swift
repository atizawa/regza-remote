import Foundation
import Observation
import RegzaApp

// Android アプリに見せる API。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core)。RegzaKey・RegzaNowPlaying・RegzaConnection・RegzaChannel は
// RegzaCore の型をそのまま使う (Java のクラスは RegzaCoreJava で作る)。
//
// 画面の状態と操作は iOS と同じ共有の ViewModel (AppViewModel とその下の画面の ViewModel) が持つ。
// ViewModel は MainActor で動き、swift-java は MainActor の同期の関数を Java に出せないので、ここに窓口を置く:
//   - snapshot() / nextSnapshot(): アプリ全体の状態 (タブ・登録の画面・接続) を返す (async なので Java の Future になる)
//   - screen() / nextScreen(): いま見えている画面の状態を返す。番組表は大きいので、全体の状態とは分け、
//     中身が変わったときだけ返す (2 秒ごとの取り直しで、番組表を渡し直さない)
//   - send(_:): 操作を送る (MainActor に順に積むだけで、すぐ返る)

/// このアプリ用のユーザー ID を新しく作る (MAC アドレスの形)。Kotlin の保存先が、初めて使うときに作って保存する
public func regzaMakeUserID() -> String {
    PairingUserID.make()
}

// MARK: - 状態

/// アプリ全体の状態 (いま見えている画面の中身は RegzaAndroidScreen)
public struct RegzaAndroidSnapshot {
    /// 選んでいるタブ ("remote"・"guide"・"channels"・"reservations")
    public var tab: String
    /// いまのタブで戻れる (タブの中で画面を開いている)
    public var canGoBack: Bool
    /// テレビの登録の画面を出している (未登録のとき、設定を開いたとき)
    public var isShowingSetup: Bool
    /// 保存すべき接続情報と番組表のアドレス。変わったら Kotlin が保存する
    public var connection: RegzaConnection
    public var guideHost: String
    public var nowPlaying: RegzaNowPlaying?
    /// テレビに接続できないときの説明
    public var connectionError: String?
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public var isSearchingTV: Bool
    /// 登録の画面を出している間だけある
    public var setup: RegzaAndroidSetup?
}

/// テレビの登録と録画サーバーの設定の画面 (TVSetupViewModel.State と ServerSetupViewModel.State)
public struct RegzaAndroidSetup {
    public var host: String
    public var user: String
    public var password: String
    public var devices: [RegzaAndroidDevice]
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
    public var guideHosts: [String]
    public var isScanningGuide: Bool
    public var guideMessage: String?
    /// 保存済みで、連携を解除できるか
    public var isGuideLinked: Bool
    /// 入力したポートが正しいか
    public var isGuideHostValid: Bool
}

/// 見つかったテレビ
public struct RegzaAndroidDevice {
    public var name: String
    public var host: String
    public var isSelected: Bool
}

// MARK: - 操作

/// 画面からの操作 (共有の ViewModel の Action に送る)
public enum RegzaAndroidAction {
    case selectTab(String)
    /// いまのタブで 1 つ戻る
    case back
    // リモコン (RemoteViewModel)
    case press(RegzaKey)
    /// 画面が見えている間、2 秒ごとに取り直す
    case startPolling
    case stopPolling
    case selectBand(RegzaChannel.Band)
    // チャンネル一覧 (ChannelListViewModel)
    case showChannels
    case reloadChannels
    /// 選局する (チャンネルのコード)
    case tune(String)
    /// 1 チャンネルの番組表を開く (チャンネルのコード)
    case openPrograms(String)
    /// 番組の詳細を開く (チャンネルのコード、番組の id)
    case openProgram(String, Int)
    // 番組表 (GuideGridViewModel)
    case showGuide
    /// 日付を選ぶ (RegzaAndroidGuide.days の何番目か)
    case selectDay(Int)
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
    // 録画予約の一覧 (ReservationListViewModel)
    case showReservations
    /// 予約を取り消す (予約の id)
    case cancelReservation(String)
    // 設定 (TVSetupViewModel・ServerSetupViewModel)
    case showSetup
    case closeSetup
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
    case save
}

// MARK: - 窓口

/// アプリ全体の窓口。アプリに 1 つ作り、画面の状態を読んで操作を送る
public final class RegzaAndroidApp {
    private let store: AndroidConnectionStore
    private let app: AppViewModel
    @MainActor private let snapshotChanges = Changes()
    @MainActor private let screenChanges = Changes()
    /// 前に返した画面の状態 (同じなら返さない)
    @MainActor private var lastScreen: ScreenKey?

    /// 保存してある値から作る。メインスレッドから呼ぶ (先に regzaSetUpMainActor を呼んでおく)
    public init(host: String, user: String, password: String, pairingUserID: String, guideHost: String) {
        _ = useSocketTransport
        let store = AndroidConnectionStore(
            connection: RegzaConnection(host: host, user: user, password: password),
            pairingUserID: pairingUserID,
            guideHost: guideHost
        )
        self.store = store
        app = MainActor.assumeIsolated {
            let app = AppViewModel(store: store)
            // 未登録なら、テレビの登録の画面から始める
            if !app.remote.state.connection.isConfigured { app.send(.showSettings) }
            return app
        }
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
        return RegzaAndroidSnapshot(
            tab: appState.tab.rawValue,
            canGoBack: !appState.path(of: appState.tab).isEmpty,
            isShowingSetup: settings != nil,
            connection: remote.connection,
            guideHost: app.guide.guideHost,
            nowPlaying: remote.nowPlaying,
            connectionError: remote.lastError?.localizedDescription,
            isSearchingTV: remote.isSearchingTV,
            setup: settings.map { settings in
                let tv = settings.tv.state
                let servers = settings.servers.state
                return RegzaAndroidSetup(
                    host: tv.draft.host,
                    user: tv.draft.user,
                    password: tv.draft.password,
                    devices: tv.devices.map { RegzaAndroidDevice(name: $0.device.name, host: $0.device.host, isSelected: $0.isSelected) },
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
                    canClose: remote.connection.isConfigured,
                    guideHost: servers.guide.host,
                    guideHosts: servers.guide.hosts,
                    isScanningGuide: servers.guide.isScanning,
                    guideMessage: servers.guide.message,
                    isGuideLinked: servers.guide.isLinked,
                    isGuideHostValid: servers.isValid
                )
            }
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
        case .guide:
            let grid = app.guideGrid.state
            return .guide(
                grid,
                band: app.remote.state.band(among: grid.bands),
                window: GuideGridViewModel.window(now: Date(), day: grid.selectedDay)
            )
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

    @MainActor private func perform(_ action: RegzaAndroidAction) {
        let tv = app.settings?.tv
        let servers = app.settings?.servers
        switch action {
        case .selectTab(let tab):
            if let tab = AppViewModel.Tab(rawValue: tab) { app.send(.selectTab(tab)) }
        case .back: app.send(.back)
        case .press(let key): app.remote.send(.press(key))
        case .startPolling: app.remote.send(.startPolling)
        case .stopPolling: app.remote.send(.stopPolling)
        case .selectBand(let band): app.remote.send(.selectBand(band))
        case .showChannels: app.channelList.send(.appear)
        case .reloadChannels: app.channelList.send(.reload)
        case .tune(let code): app.channelList.send(.tune(code))
        case .openPrograms(let code):
            app.send(.open(.channelPrograms(channelCode: code)))
        case .openProgram(let code, let id): app.send(.open(.programDetail(programID: id, channelCode: code)))
        case .showGuide: app.guideGrid.send(.load)
        case .selectDay(let index):
            let days = app.guideGrid.state.days
            if days.indices.contains(index) { app.guideGrid.send(.selectDay(days[index].date)) }
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
        case .showReservations: app.reservationList.send(.load)
        case .cancelReservation(let id): app.reservationList.send(.cancel(id))
        case .showSetup: app.send(.showSettings)
        case .closeSetup: app.send(.closeSettings)
        case .setupAppear: tv?.send(.appear)
        case .setHost(let host): tv?.send(.setHost(host))
        case .setUser(let user): tv?.send(.setUser(user))
        case .setPassword(let password): tv?.send(.setPassword(password))
        case .setPIN(let pin): tv?.send(.setPIN(pin))
        case .setShowingManualEntry(let isShowing): tv?.send(.setShowingManualEntry(isShowing))
        case .scan: tv?.send(.scan)
        case .selectDevice(let host):
            if let row = tv?.state.devices.first(where: { $0.device.host == host }) { tv?.send(.select(row.device)) }
        case .startPairing: tv?.send(.startPairing)
        case .confirmPairing: tv?.send(.confirmPairing)
        case .cancelPairing: tv?.send(.cancelPairing)
        case .test: tv?.send(.test)
        case .setGuideHost(let host): servers?.send(.setHost(.guide, host))
        case .scanGuide: servers?.send(.scan(.guide))
        case .unlinkGuide: servers?.send(.unlink(.guide))
        case .save: app.send(.saveSettings)
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
/// 変わった接続情報と番組表のアドレスは RegzaAndroidSnapshot から Kotlin が保存する
final class AndroidConnectionStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private let userID: String
    private var values: (guideHost: String, streamHost: String, ownStreamIDs: [Int])

    init(connection: RegzaConnection, pairingUserID: String, guideHost: String) {
        self.connection = connection
        userID = pairingUserID
        values = (guideHost, "", [])
    }

    func load() -> RegzaConnection { lock.withLock { connection } }
    func save(_ connection: RegzaConnection) { lock.withLock { self.connection = connection } }
    func pairingUserID() -> String { userID }

    var guideHost: String {
        get { lock.withLock { values.guideHost } }
        set { lock.withLock { values.guideHost = newValue } }
    }

    // Android にはまだライブ視聴がないので、保存しない
    var streamHost: String {
        get { lock.withLock { values.streamHost } }
        set { lock.withLock { values.streamHost = newValue } }
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { values.ownStreamIDs } }
        set { lock.withLock { values.ownStreamIDs = newValue } }
    }
}
