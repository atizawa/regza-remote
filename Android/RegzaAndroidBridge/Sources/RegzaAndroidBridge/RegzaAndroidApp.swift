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
//   - sendAppAction(_:)・sendChannelListAction(_:) など: 操作を送る (MainActor に順に積むだけで、すぐ返る。
//     scripts/generate-screen-glue.sh が Action の型ごとに作る)

// MARK: - 状態

/// アプリ全体の状態 (いま見えている画面の中身は RegzaAndroidScreen)
public struct RegzaAndroidSnapshot {
    /// アプリ全体の state (AppViewModel.State をそのまま渡す)。タブ・タブごとの path・設定や詳細を出しているか
    public var app: AppState
    /// リモコンの state (RemoteViewModel.State をそのまま渡す)。いま映っているもの・接続できないときの説明など
    public var remote: RemoteState
    /// 設定の画面の state (SettingsViewModel.State をそのまま渡す)。設定を出している間だけある
    public var setup: SettingsState?
    /// ミニプレーヤーを押して開いた、いま映っているものの詳細の state (NowPlayingViewModel.State をそのまま渡す)。開いている間だけある
    public var nowPlayingDetail: NowPlayingState?
    /// アプリで見ている (ライブ視聴の画面を出している) 間だけある
    public var player: LivePlayerState?
}

// MARK: - 窓口

/// アプリ全体の窓口。アプリに 1 つ作り、画面の状態を読んで操作を送る
public final class RegzaAndroidApp {
    private let app: AppViewModel
    @MainActor private let snapshotChanges = Changes()
    @MainActor private let screenChanges = Changes()
    /// 前に返した画面の状態 (同じなら返さない)
    @MainActor private var lastScreen: ScreenKey?

    /// Kotlin の保存先 (Keystore と SharedPreferences) で組み立てる。メインスレッドから呼ぶ (先に regzaSetUpMainActor を呼んでおく)
    public convenience init(storage: any RegzaAndroidStorage) {
        self.init(app: MainActor.assumeIsolated { AppViewModel(store: AndroidConnectionStore(storage: storage)) })
    }

    /// 組み立てた ViewModel から作る (テストでは、テレビにつながない見本の ViewModel を渡す)
    init(app: AppViewModel) {
        self.app = app
        MainActor.assumeIsolated {
            // 未登録なら、テレビの登録の画面から始める
            if !app.remote.state.isConfigured { app.send(.showSettings) }
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            Task { await app.cleanUpStreams() }
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
        return RegzaAndroidSnapshot(
            app: appState,
            remote: remote,
            setup: settings?.state,
            nowPlayingDetail: nowPlaying,
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

    /// 操作 (AppAction・ChannelListAction など) を、AppViewModel と開いている画面の ViewModel に手前から渡してみて、受け取ったところで止める。
    /// 画面ごとの send と perform は、scripts/generate-screen-glue.sh が Generated/ScreenActions.swift に作る
    @MainActor func route(_ deliver: (AnyObject) -> Bool) {
        // アプリ全体の操作 (AppAction) は AppViewModel が受け取る
        for viewModel in [app] + app.openViewModels {
            if deliver(viewModel) { return }
        }
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
