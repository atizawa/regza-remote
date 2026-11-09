import Foundation
import Observation
import RegzaApp

// Android アプリに見せる窓口。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core。mise run build-swift が作り、設定は
// ../RegzaAndroid/RegzaAndroidBridge.swift-java.config)。Android 専用の部品 (Looper・BoringSSL・swift-java) に頼らないので、
// Mac の swift test で確かめられる。
//
// 画面の状態と操作は iOS と同じ共有の ViewModel (AppViewModel とその下の画面の ViewModel) が持ち、
// state と操作の型 (ChannelListState・ChannelListAction など) もそのまま渡す。ViewModel は MainActor で動き、
// swift-java は MainActor の同期の関数を Java に出せないので、ここに窓口を置く。窓口の関数は
// scripts/generate-screen-glue.sh が型ごとに作る (Generated/):
//   - channelListState(route:) / nextChannelListState(route:after:) など: ViewModel の state を返す。
//     next は渡した state から変わるまで待つ (async なので Java の Future になる)。画面ごとに別々に待つので、
//     2 秒ごとのリモコンの取り直しで番組表を渡し直すことはない
//   - sendAppAction(_:)・sendChannelListAction(_:) など: 操作を送る (MainActor に順に積むだけで、すぐ返る)

/// アプリ全体の窓口。アプリに 1 つ作り、ViewModel の state を読んで操作を送る
public final class RegzaAndroidApp {
    private let app: AppViewModel

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

    // MARK: state

    /// AppViewModel と開いている画面の ViewModel (手前から)
    @MainActor private var viewModels: [AnyObject] { [app] + app.openViewModels }

    /// route の画面の ViewModel の state。route が nil なら、開いている ViewModel のうち state を返せる最初のもの
    /// (タブの最初の画面・リモコン・設定などは 1 つずつしかない)。開いていなければ nil
    @MainActor func state<State>(route: AppRoute?, _ state: @MainActor (AnyObject) -> State?) -> State? {
        if let route { return app.viewModel(for: route).flatMap(state) }
        return viewModels.lazy.compactMap(state).first
    }

    /// state が last から変わるまで待って返す (呼ぶ前に変わっていれば、すぐ返す)
    @MainActor func nextState<State: Equatable>(
        route: AppRoute?, after last: State?, _ state: @MainActor (AnyObject) -> State?
    ) async -> State? {
        let changes = Changes()
        while true {
            let current = changes.track { self.state(route: route, state) }
            if current != last { return current }
            await changes.wait()
        }
    }

    // MARK: 操作

    /// 操作 (AppAction・ChannelListAction など) を、AppViewModel と開いている画面の ViewModel に手前から渡してみて、受け取ったところで止める
    @MainActor func route(_ deliver: (AnyObject) -> Bool) {
        for viewModel in viewModels {
            if deliver(viewModel) { return }
        }
    }
}

/// URL を文字列にする (ライブ視聴の LivePlayerPhase.ready の URL を ExoPlayer に渡す)。
/// swift-java は enum の値にしか使っていない型の Java のクラスを作らないので、ここで URL を使って作らせる役目もある
public func regzaURLString(_ url: URL) -> String { url.absoluteString }

/// 読んだ値の変わり目を知らせる。読んだ値を見張り、変わったら待っている側を起こす
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
