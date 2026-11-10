import Foundation
import Observation
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
    let app: AppViewModel

    /// Kotlin の Flow が待っている state。Java の Future を取り消しても swift-java が Swift の Task を取り消さないので、
    /// Flow ごとの番号で待機を終わらせる。終了と待機の開始が前後しても取りこぼさないよう、終了済みも一時的に覚える。
    @MainActor private var stateWaits: [Int64: StateWait] = [:]

    /// Kotlin の保存先 (Keystore と SharedPreferences) で組み立てる。Android では先に regzaSetUpMainActor を呼んでおく
    public convenience init(storage: any RegzaAndroidStorage) {
        self.init(app: onMainActor { AppViewModel(store: AndroidConnectionStore(storage: storage)) })
    }

    /// 組み立てた ViewModel から作る (テストでは、テレビにつながない見本の ViewModel を渡す)
    init(app: AppViewModel) {
        self.app = app
        onMainActor {
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
        route: AppRoute?, after last: State?, waitID: Int64, _ state: @MainActor (AnyObject) -> State?
    ) async -> State? {
        let changes = Changes()
        switch stateWaits[waitID] {
        case .cancelled?:
            // Flow の終了が、swift-java がこの Task を MainActor で始めるより先だった
            stateWaits[waitID] = nil
            return nil
        case nil:
            stateWaits[waitID] = .waiting(changes)
        case .waiting?, .completed?:
            preconditionFailure("同じ state の待機番号が重なっています: \(waitID)")
        }
        while true {
            if case .cancelled? = stateWaits[waitID] {
                stateWaits[waitID] = nil
                return nil
            }
            let current = changes.track { self.state(route: route, state) }
            if current != last {
                // Kotlin が Future の結果を受け取って endStateWait を呼ぶまで、完了したことを覚えておく。
                // 結果を返す直前に Flow が終了しても、後から来た endStateWait を開始前の終了と取り違えないため。
                stateWaits[waitID] = .completed
                return current
            }
            await changes.wait()
        }
    }

    /// Kotlin の Flow が 1 回の nextState の待機を使い終えたことを知らせる。
    /// Flow が取り消されたときは待っている continuation を起こし、swift-java の Task と JNI の参照を解放させる。
    public func endStateWait(_ id: Int64) async {
        await MainActor.run {
            switch self.stateWaits[id] {
            case .waiting(let changes):
                self.stateWaits[id] = .cancelled
                changes.changed()
            case .completed?:
                self.stateWaits[id] = nil
            case .cancelled?:
                break
            case nil:
                // swift-java が nextState の Task を始める前に、Flow の終了が届いた
                self.stateWaits[id] = .cancelled
            }
        }
    }

    /// 残っている state の待機の数 (テスト用)。Flow を止めたあとに、Swift の待機が残っていないことを確かめる。
    /// Mac のテストは MainActor から直接読み、Android の端末のテストは Java から pendingStateWaitCount() で読む
    @MainActor var stateWaitCount: Int { stateWaits.count }

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

/// Kotlin の Flow から始めた state の待機
@MainActor
private enum StateWait {
    case waiting(Changes)
    case completed
    case cancelled
}

/// MainActor で動かして結果を返す。アプリはメインスレッドから呼ぶのでそのまま動かし、
/// JVM で動かすテストのようにほかのスレッドから呼ばれたときは、メインスレッドで動き終わるのを待つ
func onMainActor<Value>(_ body: @MainActor () -> Value) -> Value {
    if Thread.isMainThread { return MainActor.assumeIsolated(body) }
    return DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
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

    fileprivate func changed() {
        hasChanged = true
        waiter?.resume()
        waiter = nil
    }
}
