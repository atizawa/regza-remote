#if os(iOS)
import RegzaApp
import RegzaAppContainer
import RegzaLiveActivity
import RegzaRemoteViews
import SwiftUI

/// アプリの入口。アプリのプロセスに 1 つだけある ViewModel (RegzaAppContainer) を、画面 (RegzaRemoteViews の AppScreen) に渡す。
/// 終了時の後片づけなど、Domain の型が要るものはここで受け持つ (画面からは Domain が見えない)
public struct RootView: View {
    @State private var app: AppViewModel
    @State private var liveActivity: LiveActivityModel
    private let debugPlayer: LivePlayerViewModel?

    public init() {
        // Live Activity のボタンや Siri と同じものを使う
        let container = RegzaAppContainer.shared
        let app = container.app
        var debugPlayer: LivePlayerViewModel?
        #if DEBUG
        if let tab = container.sampleInitialTab { app.send(.selectTab(tab)) }
        // 開発用: 起動引数 -ShowSettings YES で設定画面を開いておく
        if UserDefaults.standard.bool(forKey: "ShowSettings") { app.send(.showSettings) }
        // 開発用: 起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で、すぐ再生画面を開く
        if let host = UserDefaults.standard.string(forKey: "LiveHost"),
            let channelCode = UserDefaults.standard.string(forKey: "LiveChannel")
        {
            debugPlayer = app.debugLivePlayer(streamHost: host, channelCode: channelCode)
        }
        #endif
        _app = State(initialValue: app)
        _liveActivity = State(initialValue: container.liveActivity)
        self.debugPlayer = debugPlayer
    }

    public var body: some View {
        AppScreen(app: app, liveActivity: liveActivity, debugPlayer: debugPlayer)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                // 終了するときも、ライブ視聴の配信を止めてみる (届かなければ次に開いたときに止める)
                let store = RegzaAppContainer.shared.store
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
