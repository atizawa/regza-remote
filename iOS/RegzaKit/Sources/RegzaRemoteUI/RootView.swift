#if os(iOS)
import RegzaApp
import RegzaAppContainer
import RegzaLiveActivity
import RegzaRemoteViews
import SwiftUI

/// アプリの入口。アプリのプロセスに 1 つだけある ViewModel (RegzaAppContainer) を、画面 (RegzaRemoteViews の AppScreen) に渡す。
/// 終了時の後片づけなど、Domain の型が要るものはここで受け持つ (画面からは Domain が見えない)
public struct RootView: View {
    @State private var appViewModel: AppViewModel
    @State private var liveActivity: LiveActivityModel
    private let debugPlayerViewModel: LivePlayerViewModel?

    public init() {
        // Live Activity のボタンや Siri と同じものを使う
        let container = RegzaAppContainer.shared
        let appViewModel = container.appViewModel
        var debugPlayerViewModel: LivePlayerViewModel?
        #if DEBUG
        if let tab = container.sampleInitialTab { appViewModel.send(.selectTab(tab)) }
        // 開発用: 起動引数 -ShowSettings YES で設定画面を開いておく
        if UserDefaults.standard.bool(forKey: "ShowSettings") { appViewModel.send(.showSettings) }
        // 開発用: 起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で、すぐ再生画面を開く
        if let host = UserDefaults.standard.string(forKey: "LiveHost"),
            let channelCode = UserDefaults.standard.string(forKey: "LiveChannel")
        {
            debugPlayerViewModel = appViewModel.debugLivePlayer(streamHost: host, channelCode: channelCode)
        }
        #endif
        _appViewModel = State(initialValue: appViewModel)
        _liveActivity = State(initialValue: container.liveActivity)
        self.debugPlayerViewModel = debugPlayerViewModel
    }

    public var body: some View {
        AppScreen(appViewModel: appViewModel, liveActivity: liveActivity, debugPlayerViewModel: debugPlayerViewModel)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                // 終了するときも、ライブ視聴の配信を止めてみる (届かなければ次に開いたときに止める)
                let preferencesManager = RegzaAppContainer.shared.preferencesManager
                let host = preferencesManager.value(forKey: .streamHost) ?? ""
                guard !host.isEmpty, !preferencesManager.integers(forKey: .ownStreamIDs).isEmpty else { return }
                let epgStationAPIClient = EPGStationAPIClient(host: host)
                let semaphore = DispatchSemaphore(value: 0)
                Task.detached {
                    await EPGStationStreamRepository.cleanUp(epgStationAPIClient, preferencesManager: preferencesManager)
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 2)
            }
    }
}
#endif
