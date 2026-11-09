#if os(iOS)
import RegzaApp
import RegzaLiveActivity
import RegzaRemoteViews
import RegzaSample
import SwiftUI

/// アプリの入口 (組み立て)。どの Repository を使うかを決めて ViewModel を作り、画面 (RegzaRemoteViews の AppView) に渡す。
/// Live Activity との連携や終了時の後片づけなど、Domain の型が要るものはここで受け持つ (画面からは Domain が見えない)
public struct RemoteView: View {
    @State private var app: AppViewModel
    @State private var liveActivity: LiveActivityModel
    private let debugPlayer: LivePlayerViewModel?

    public init() {
        // Live Activity のボタン (App Intents) と同じ保存先とリモコンを使う
        var app = AppViewModel(store: RegzaRemoteService.store, remote: RegzaRemoteService.remote)
        var debugPlayer: LivePlayerViewModel?
        #if DEBUG
        // 開発用: 起動引数 -SampleData YES で、テレビにつながない見本の Repository で組み立てる
        if SampleData.isEnabled { app = SampleData.makeApp() }
        #endif
        let liveActivity = LiveActivityModel(remote: app.remote)
        app.remote.setActivityObserver(liveActivity)
        #if DEBUG
        if let tab = SampleData.initialTab { app.send(.selectTab(tab)) }
        // 開発用: 起動引数 -ShowSettings YES で設定画面を開いておく
        if UserDefaults.standard.bool(forKey: "ShowSettings") { app.send(.showSettings) }
        // 開発用: 起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で、すぐ再生画面を開く
        if let host = UserDefaults.standard.string(forKey: "LiveHost"),
           let channelCode = UserDefaults.standard.string(forKey: "LiveChannel") {
            debugPlayer = app.debugLivePlayer(streamHost: host, channelCode: channelCode)
        }
        #endif
        _app = State(initialValue: app)
        _liveActivity = State(initialValue: liveActivity)
        self.debugPlayer = debugPlayer
    }

    public var body: some View {
        AppView(app: app, liveActivity: liveActivity, debugPlayer: debugPlayer)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                // 終了するときも、ライブ視聴の配信を止めてみる (届かなければ次に開いたときに止める)
                let store = RegzaRemoteService.store
                guard !store.streamHost.isEmpty, !store.ownStreamIDs.isEmpty else { return }
                let server = EPGStation(host: store.streamHost)
                let semaphore = DispatchSemaphore(value: 0)
                Task.detached {
                    await EPGStationStreamRepository.cleanUp(server, store: store)
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 2)
            }
    }
}
#endif
