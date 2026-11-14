#if os(iOS)
import RegzaApp
import AppServices
import LiveActivity
import UI
import SwiftUI

/// アプリの入口。アプリのプロセスに 1 つだけある ViewModel (AppContainer) を、画面 (UI の AppScreen) に渡す。
/// アプリの終了通知は AppServices へ渡す。
struct RootView: View {
    @State private var appViewModel: AppViewModel
    @State private var liveActivity: LiveActivityModel
    @SceneStorage("regza.ui") private var savedStateJSON = ""
    @Environment(\.scenePhase) private var scenePhase
    private let debugPlayerViewModel: LivePlayerViewModel?
    private let appContainer: AppContainer

    init(appContainer: AppContainer = .shared) {
        // Live Activity のボタンや Siri と同じものを使う
        self.appContainer = appContainer
        let appViewModel = appContainer.appViewModel
        var debugPlayerViewModel: LivePlayerViewModel?
        #if DEBUG
        if let tab = appContainer.sampleInitialTab { appViewModel.send(.selectTab(tab)) }
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
        _liveActivity = State(initialValue: appContainer.liveActivity)
        self.debugPlayerViewModel = debugPlayerViewModel
    }

    var body: some View {
        AppScreen(appViewModel: appViewModel, liveActivity: liveActivity, debugPlayerViewModel: debugPlayerViewModel)
            .preferredColorScheme(appViewModel.appearance.preferredColorScheme)
            .onAppear {
                appContainer.restoreUIState(savedStateJSON)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, let json = appContainer.saveUIState() {
                    savedStateJSON = json
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                appContainer.applicationWillTerminate()
            }
    }
}
#endif
