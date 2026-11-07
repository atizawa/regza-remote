import Foundation
import Observation
import RegzaCore

// Android アプリに見せる API。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core)。RegzaKey・RegzaNowPlaying・RegzaConnection・RegzaChannel は
// RegzaCore の型をそのまま使う (Java のクラスは RegzaCoreJava で作る)。
//
// 画面の状態と操作は iOS と同じ共有の ViewModel (AppViewModel とその下の画面の ViewModel) が持つ。
// ViewModel は MainActor で動き、swift-java は MainActor の同期の関数を Java に出せないので、ここに窓口を置く:
//   - snapshot() / nextSnapshot(): 画面に出す状態をまとめて返す (async なので Java の Future になる)
//   - send(_:): 操作を送る (MainActor に順に積むだけで、すぐ返る)

/// このアプリ用のユーザー ID を新しく作る (MAC アドレスの形)。Kotlin の保存先が、初めて使うときに作って保存する
public func regzaMakeUserID() -> String {
    RegzaPairing.makeUserID()
}

// MARK: - 状態

/// 画面に出す状態をまとめたもの (iOS の画面が ViewModel の state から読むものと同じ)
public struct RegzaAndroidSnapshot {
    /// 選んでいるタブ ("remote" か "channels")
    public var tab: String
    /// テレビの登録の画面を出している (未登録のとき、登録し直すとき)
    public var isShowingSetup: Bool
    /// 保存すべき接続情報。変わったら Kotlin が保存する
    public var connection: RegzaConnection
    public var nowPlaying: RegzaNowPlaying?
    /// テレビに接続できないときの説明
    public var connectionError: String?
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public var isSearchingTV: Bool
    public var channelList: RegzaAndroidChannelList
    /// 登録の画面を出している間だけある
    public var setup: RegzaAndroidSetup?
}

/// チャンネル一覧の画面 (ChannelListViewModel.State)
public struct RegzaAndroidChannelList {
    public var isLoading: Bool
    /// 一覧の代わりに出す、取得できなかった説明
    public var loadErrorMessage: String?
    /// 切り替えられなかったときの説明
    public var tuneError: String?
    /// 切り替え中のチャンネルのコード
    public var tuningChannelCode: String?
    public var bands: [RegzaChannel.Band]
    public var band: RegzaChannel.Band?
    public var rows: [RegzaAndroidChannelRow]
}

public struct RegzaAndroidChannelRow {
    public var channel: RegzaChannel
    public var programName: String?
    public var isNowPlaying: Bool
    /// 控えめに出す (同じ放送局のサブチャンネル)
    public var isSubchannel: Bool
}

/// テレビの登録の画面 (TVSetupViewModel.State)
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
    // リモコン (RemoteViewModel)
    case press(RegzaKey)
    /// 画面が見えている間、2 秒ごとに取り直す
    case startPolling
    case stopPolling
    // チャンネル一覧 (ChannelListViewModel)
    case showChannels
    case reloadChannels
    case selectBand(RegzaChannel.Band)
    case tune(RegzaChannel)
    // テレビの登録 (TVSetupViewModel)
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
    case save
}

// MARK: - 窓口

/// アプリ全体の窓口。アプリに 1 つ作り、画面の状態を読んで操作を送る
public final class RegzaAndroidApp {
    private let store: AndroidConnectionStore
    private let app: AppViewModel
    /// 前に返した状態から変わったか (変わるのを待つ間に起きた変化も逃さない)
    @MainActor private var hasChanged = false
    @MainActor private var waiter: CheckedContinuation<Void, Never>?

    /// 保存してある値から作る。メインスレッドから呼ぶ (先に regzaSetUpMainActor を呼んでおく)
    public init(host: String, user: String, password: String, pairingUserID: String) {
        _ = useSocketTransport
        let store = AndroidConnectionStore(
            connection: RegzaConnection(host: host, user: user, password: password), pairingUserID: pairingUserID
        )
        self.store = store
        app = MainActor.assumeIsolated {
            let app = AppViewModel(store: store)
            // 未登録なら、テレビの登録の画面から始める
            if !app.remote.state.connection.isConfigured { app.send(.showSettings) }
            return app
        }
    }

    /// いまの状態
    public func snapshot() async -> RegzaAndroidSnapshot {
        await trackedSnapshot()
    }

    /// 前に返したときから状態が変わるまで待って、変わった状態を返す
    public func nextSnapshot() async -> RegzaAndroidSnapshot {
        await waitForChange()
        return await trackedSnapshot()
    }

    /// 操作を送る。送った順に MainActor で処理する
    public func send(_ action: RegzaAndroidAction) {
        Task { @MainActor in self.perform(action) }
    }

    // MARK: 状態の変化を待つ

    @MainActor private func trackedSnapshot() -> RegzaAndroidSnapshot {
        hasChanged = false
        return withObservationTracking { makeSnapshot() } onChange: { [weak self] in
            // 変わる直前に呼ばれるので、変わり終わってから知らせる
            Task { @MainActor in self?.markChanged() }
        }
    }

    @MainActor private func markChanged() {
        hasChanged = true
        waiter?.resume()
        waiter = nil
    }

    @MainActor private func waitForChange() async {
        if hasChanged { return }
        await withCheckedContinuation { waiter = $0 }
    }

    // MARK: ViewModel の state から作る

    @MainActor private func makeSnapshot() -> RegzaAndroidSnapshot {
        let appState = app.state
        let remote = app.remote.state
        let channels = app.channelList.state
        let tv = appState.isShowingSettings ? app.settings?.tv : nil
        return RegzaAndroidSnapshot(
            tab: appState.tab.rawValue,
            isShowingSetup: tv != nil,
            connection: remote.connection,
            nowPlaying: remote.nowPlaying,
            connectionError: remote.lastError?.localizedDescription,
            isSearchingTV: remote.isSearchingTV,
            channelList: RegzaAndroidChannelList(
                isLoading: channels.isLoading,
                loadErrorMessage: channels.loadErrorMessage,
                tuneError: channels.tuneError,
                tuningChannelCode: channels.tuning?.code,
                bands: channels.bands,
                band: channels.band,
                rows: channels.rows.map {
                    RegzaAndroidChannelRow(
                        channel: $0.channel, programName: $0.programName, isNowPlaying: $0.isNowPlaying, isSubchannel: $0.isSubchannel
                    )
                }
            ),
            setup: tv.map { tv in
                let state = tv.state
                return RegzaAndroidSetup(
                    host: state.draft.host,
                    user: state.draft.user,
                    password: state.draft.password,
                    devices: state.devices.map { RegzaAndroidDevice(name: $0.device.name, host: $0.device.host, isSelected: $0.isSelected) },
                    isScanning: state.isScanning,
                    scanMessage: state.scanMessage,
                    isWaitingForPIN: state.isWaitingForPIN,
                    pin: state.pin,
                    isPairing: state.isPairing,
                    pairingMessage: state.pairingMessage,
                    isRegistered: state.isRegistered,
                    hasRegistered: state.hasRegistered,
                    isShowingManualEntry: state.isShowingManualEntry,
                    isTesting: state.isTesting,
                    testResult: state.testResult,
                    canSave: state.canSave,
                    canClose: remote.connection.isConfigured
                )
            }
        )
    }

    @MainActor private func perform(_ action: RegzaAndroidAction) {
        let tv = app.settings?.tv
        switch action {
        case .selectTab(let tab):
            if let tab = AppViewModel.Tab(rawValue: tab) { app.send(.selectTab(tab)) }
        case .press(let key): app.remote.send(.press(key))
        case .startPolling: app.remote.send(.startPolling)
        case .stopPolling: app.remote.send(.stopPolling)
        case .showChannels: app.channelList.send(.appear)
        case .reloadChannels: app.channelList.send(.reload)
        case .selectBand(let band): app.remote.send(.selectBand(band))
        case .tune(let channel): app.channelList.send(.tune(channel))
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
        case .save: app.send(.saveSettings)
        }
    }
}

/// Android の保存先。値は Kotlin が Keystore で暗号化して保存しているものを起動時に受け取り、
/// 変わった接続情報は RegzaAndroidSnapshot.connection から Kotlin が保存する
final class AndroidConnectionStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private let userID: String
    private var values = (guideHost: "", streamHost: "", ownStreamIDs: [Int]())

    init(connection: RegzaConnection, pairingUserID: String) {
        self.connection = connection
        userID = pairingUserID
    }

    func load() -> RegzaConnection { lock.withLock { connection } }
    func save(_ connection: RegzaConnection) { lock.withLock { self.connection = connection } }
    func pairingUserID() -> String { userID }

    // Android にはまだ番組表とライブ視聴がないので、保存しない
    var guideHost: String {
        get { lock.withLock { values.guideHost } }
        set { lock.withLock { values.guideHost = newValue } }
    }

    var streamHost: String {
        get { lock.withLock { values.streamHost } }
        set { lock.withLock { values.streamHost = newValue } }
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { values.ownStreamIDs } }
        set { lock.withLock { values.ownStreamIDs = newValue } }
    }
}
