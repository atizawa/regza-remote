import Foundation
import RegzaApp

// Android アプリに見せる窓口。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core。mise run build-swift が作り、設定は
// ../RegzaAndroid/RegzaAndroidBridge.swift-java.config)。Android 専用の部品 (Looper・BoringSSL・swift-java) に頼らないので、
// Mac の swift test で確かめられる。
//
// 画面の状態と操作は iOS と同じ共有の ViewModel (AppViewModel とその下の画面の ViewModel) が持ち、
// 画面ごとの state と操作の型 (State/・Action/ に置いた型) もそのまま渡す。ViewModel は MainActor で動き、
// swift-java は MainActor の同期の関数を Java に出せないので、ここに窓口を置く。窓口の関数は
// Android/ScreenGlue の screen-glue が型ごとに作る (Generated/):
//   - <State の型 (先頭は小文字)>(route:) / next<State の型>(route:after:waitID:): ViewModel の state を返す。
//     next は渡した state から変わるまで待つ (async なので Java の Future になる)。Flow が終わったら
//     endStateWait で Swift の待機も終える。画面ごとに別々に待つので、2 秒ごとのリモコンの取り直しで番組表を渡し直すことはない
//   - send<Action の型>(_:): 操作を送る (MainActor に順に積むだけで、すぐ返る)

/// アプリ全体の窓口。アプリに 1 つ作り、ViewModel の state を読んで操作を送る
public final class RegzaAndroidApp {
    let appViewModel: AppViewModel

    private let stateWaitRegistry: StateWaitRegistry

    /// 組み立てた ViewModel から作る (テストでは、テレビにつながない見本の ViewModel を渡す)
    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        self.stateWaitRegistry = onMainActor {
            // 未登録なら、テレビの登録の画面から始める
            if !appViewModel.remoteViewModel.state.isConfigured { appViewModel.send(.showSettings) }
            // 前回、強制終了などで止められずに残ったライブ視聴の配信を止める
            Task { await appViewModel.cleanUpStreams() }
            return StateWaitRegistry()
        }
    }

    // MARK: state

    /// AppViewModel と開いている画面の ViewModel (手前から)
    @MainActor private var viewModels: [AnyObject] { [appViewModel] + appViewModel.openViewModels }

    /// route の画面の ViewModel の state。route が nil なら、開いている ViewModel のうち state を返せる最初のもの
    /// (タブの最初の画面・リモコン・設定などは 1 つずつしかない)。開いていなければ nil
    @MainActor func state<State>(route: AppRoute?, _ state: @MainActor (AnyObject) -> State?) -> State? {
        if let route { return appViewModel.viewModel(for: route).flatMap(state) }
        return viewModels.lazy.compactMap(state).first
    }

    /// state が last から変わるまで待って返す (呼ぶ前に変わっていれば、すぐ返す)
    @MainActor func nextState<State: Equatable>(
        route: AppRoute?, after last: State?, waitID: Int64, _ state: @MainActor (AnyObject) -> State?
    ) async -> State? {
        await stateWaitRegistry.next(after: last, waitID: waitID) {
            self.state(route: route, state)
        }
    }

    /// Kotlin の Flow が 1 回の nextState の待機を使い終えたことを知らせる。
    /// Flow が取り消されたときは待っている continuation を起こし、swift-java の Task と JNI の参照を解放させる。
    public func endStateWait(_ id: Int64) async {
        await stateWaitRegistry.end(id)
    }

    /// 残っている state の待機の数 (テスト用)。Flow を止めたあとに、Swift の待機が残っていないことを確かめる。
    /// Mac のテストは MainActor から直接読み、Android の端末のテストは Java から pendingStateWaitCount() で読む
    @MainActor var stateWaitCount: Int { stateWaitRegistry.count }

    /// stateWaitCount を Java から読む (テスト用。Android の端末のテスト AndroidRuntimeSmokeTest が使う)
    public func pendingStateWaitCount() async -> Int64 {
        await MainActor.run { Int64(stateWaitCount) }
    }

    // MARK: 操作

    /// 操作を、AppViewModel と開いている画面の ViewModel に手前から渡してみて、受け取ったところで止める
    @MainActor func route(_ deliver: (AnyObject) -> Bool) {
        for viewModel in viewModels {
            if deliver(viewModel) { return }
        }
    }
}

/// MainActor で動かして結果を返す。アプリはメインスレッドから呼ぶのでそのまま動かし、
/// JVM で動かすテストのようにほかのスレッドから呼ばれたときは、メインのキューで動き終わるのを待つ
func onMainActor<Value>(_ body: @MainActor () -> Value) -> Value {
    // MainActor の処理はメインのキューで動く。Linux では、メインのキューがメインスレッド以外で動くこともあるので、
    // スレッドではなくキューで見分ける (メインのキューの上で main.sync を呼ぶと、libdispatch が止める)
    if Thread.isMainThread || DispatchQueue.getSpecific(key: mainQueueKey) == true { return MainActor.assumeIsolated(body) }
    return DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
}

/// メインのキューの上で動いているかを見分ける印
private let mainQueueKey: DispatchSpecificKey<Bool> = {
    let key = DispatchSpecificKey<Bool>()
    DispatchQueue.main.setSpecific(key: key, value: true)
    return key
}()

/// URL を文字列にする (ライブ視聴の LivePlayerPhase.ready の URL を ExoPlayer に渡す)。
/// swift-java は enum の値にしか使っていない型の Java のクラスを作らないので、ここで URL を使って作らせる役目もある
public func regzaURLString(_ url: URL) -> String { url.absoluteString }
