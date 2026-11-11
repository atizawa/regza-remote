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

    public init(
        appViewModel: AppViewModel,
        secureStorageManager: SecureStorageManager,
        preferencesManager: PreferencesManager
    ) {
        self.secureStorageManager = secureStorageManager
        self.preferencesManager = preferencesManager
        self.appViewModel = appViewModel
        liveActivity = LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel)
    }

    private convenience init() {
        let secureStorageManager = SecureStorageManager(storage: KeychainStorage())
        let preferencesManager = PreferencesManager(storage: UserDefaultsStorage())
        #if DEBUG
        if SampleData.isEnabled {
            self.init(
                appViewModel: SampleData.makeApp(),
                secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
            return
        }
        #endif
        let appViewModel = AppFactory.makeLiveAppViewModel(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, transport: URLSessionTransport())
        self.init(appViewModel: appViewModel, secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
    }

}

#if DEBUG
extension AppContainer {
    /// 開発用: 起動引数 -InitialTab guide などで選ぶ最初のタブ
    public var sampleInitialTab: AppViewModel.Tab? { SampleData.initialTab }
}
#endif
#endif
