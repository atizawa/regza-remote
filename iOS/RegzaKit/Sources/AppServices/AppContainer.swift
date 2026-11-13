#if os(iOS)
import Foundation
import RegzaApp
import LiveActivity

/// アプリのプロセスに 1 つだけ置く、アプリ全体の ViewModel の組み立て (Composition Root)。
/// 画面と、画面のない入口 (Live Activity・ウィジェット・コントロールセンターのボタン、Siri、閉じている間の更新) が同じものを使う。
/// 画面のない入口でアプリが起こされたときも、最初に使われたときに作る (作るだけでは通信しない)
@MainActor
public final class AppContainer {
    public static let shared = AppContainer()

    /// Repository に渡す、OS の保存先を包んだ Manager。
    public let secureStorageManager: SecureStorageManager
    public let preferencesManager: PreferencesManager
    public let appViewModel: AppViewModel
    /// ロック画面と Dynamic Island の表示。リモコンの state を見て更新する
    public let liveActivity: LiveActivityModel
    private let appLifecycleService: AppLifecycleService
    private let appStateRestoration: AppStateRestoration?

    public init(
        appViewModel: AppViewModel,
        secureStorageManager: SecureStorageManager,
        preferencesManager: PreferencesManager,
        httpTransport: any HTTPTransport = URLSessionTransport(),
        restoresUIState: Bool = true
    ) {
        self.secureStorageManager = secureStorageManager
        self.preferencesManager = preferencesManager
        self.appViewModel = appViewModel
        liveActivity = LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel)
        appLifecycleService = AppLifecycleService(preferencesManager: preferencesManager, httpTransport: httpTransport)
        appStateRestoration = restoresUIState ? AppStateRestoration(appViewModel: appViewModel) : nil
    }

    private convenience init() {
        let secureStorageManager = SecureStorageManager(storage: KeychainStorage())
        let preferencesManager = PreferencesManager(storage: UserDefaultsStorage())
        let httpTransport = URLSessionTransport()
        #if DEBUG
        if SampleData.isEnabled {
            let appViewModel = SampleData.makeApp()
            self.init(
                appViewModel: appViewModel,
                secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, httpTransport: httpTransport,
                restoresUIState: false)
            Task { await SampleData.prepareScreens(appViewModel) }
            return
        }
        #endif
        let appViewModel = AppFactory.makeLiveAppViewModel(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, transport: httpTransport)
        self.init(
            appViewModel: appViewModel, secureStorageManager: secureStorageManager,
            preferencesManager: preferencesManager, httpTransport: httpTransport)
    }

    public func applicationWillTerminate() {
        appLifecycleService.applicationWillTerminate()
    }

    public func restoreUIState(_ json: String) {
        appStateRestoration?.restore(json)
    }

    public func saveUIState() -> String? {
        appStateRestoration?.save()
    }

}

#if DEBUG
extension AppContainer {
    /// 開発用: 起動引数 -InitialTab guide などで選ぶ最初のタブ
    public var sampleInitialTab: AppViewModel.Tab? { SampleData.initialTab }
}
#endif
#endif
