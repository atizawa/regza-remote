#if os(iOS)
import Foundation
import RegzaApp
import LiveActivity
import Localization

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
        httpTransport: any HTTPTransport = URLSessionTransport()
    ) {
        self.secureStorageManager = secureStorageManager
        self.preferencesManager = preferencesManager
        self.appViewModel = appViewModel
        liveActivity = LiveActivityModel(remoteViewModel: appViewModel.remoteViewModel)
        appLifecycleService = AppLifecycleService(preferencesManager: preferencesManager, httpTransport: httpTransport)
        appStateRestoration = AppStateRestoration(appViewModel: appViewModel)
    }

    private convenience init() {
        // 共有の Swift の文言を、組み立てる前にこのアプリの言語にする
        CoreStringsSetup.install()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let argumentServer = arguments.firstIndex(of: "-UITestServer").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        if let server = ProcessInfo.processInfo.environment["UITEST_SERVER"] ?? argumentServer, !server.isEmpty {
            let secureStorageManager = SecureStorageManager(storage: MemorySecureStorage())
            let preferencesManager = PreferencesManager(
                storage: MemoryPreferencesStorage(values: [.host: server, .guideHost: server, .streamHost: server]))
            let transport = URLSessionTransport()
            self.init(
                appViewModel: AppFactory.makeLiveAppViewModel(
                    secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, transport: transport),
                secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, httpTransport: transport)
            return
        }
        #endif
        let secureStorageManager = SecureStorageManager(storage: KeychainStorage())
        let preferencesManager = PreferencesManager(storage: UserDefaultsStorage())
        let httpTransport = URLSessionTransport()
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

#endif
