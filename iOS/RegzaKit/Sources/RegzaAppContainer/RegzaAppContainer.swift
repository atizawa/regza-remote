#if os(iOS)
import Foundation
import RegzaApp
import RegzaAppleStorage
import RegzaLiveActivity

/// アプリのプロセスに 1 つだけ置く、アプリ全体の ViewModel の組み立て (Composition Root)。
/// 画面と、画面のない入口 (Live Activity・ウィジェット・コントロールセンターのボタン、Siri、閉じている間の更新) が同じものを使う。
/// 画面のない入口でアプリが起こされたときも、最初に使われたときに作る (作るだけでは通信しない)
@MainActor
public final class RegzaAppContainer {
    public static let shared = RegzaAppContainer()

    /// Repository に渡す、OS の保存先を包んだ Manager。
    public let secureStorageManager: SecureStorageManager
    public let preferencesManager: PreferencesManager
    public let appViewModel: AppViewModel
    /// ロック画面と Dynamic Island の表示。リモコンの state を見て更新する
    public let liveActivity: LiveActivityModel

    private init() {
        secureStorageManager = SecureStorageManager(storage: KeychainStorage())
        preferencesManager = PreferencesManager(storage: UserDefaultsStorage())
        var appViewModel = AppViewModel(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
        #if DEBUG
        // 開発用: 起動引数 -SampleData YES で、テレビにつながない見本の Repository で組み立てる
        if SampleData.isEnabled { appViewModel = SampleData.makeApp() }
        #endif
        self.appViewModel = appViewModel
        liveActivity = LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel)
    }

}

#if DEBUG
extension RegzaAppContainer {
    /// 開発用: 起動引数 -InitialTab guide などで選ぶ最初のタブ
    public var sampleInitialTab: AppViewModel.Tab? { SampleData.initialTab }
}
#endif
#endif
