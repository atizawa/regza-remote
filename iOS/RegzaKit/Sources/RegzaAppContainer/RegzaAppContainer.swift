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

    /// 接続情報の保存先 (キーチェーン)
    public let store: KeychainConnectionStore
    public let app: AppViewModel
    /// ロック画面と Dynamic Island の表示。リモコンの state を見て更新する
    public let liveActivity: LiveActivityModel

    private init() {
        store = KeychainConnectionStore()
        var app = AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), guide: Self.makeGuide(store)))
        #if DEBUG
        // 開発用: 起動引数 -SampleData YES で、テレビにつながない見本の Repository で組み立てる
        if SampleData.isEnabled { app = SampleData.makeApp() }
        #endif
        self.app = app
        liveActivity = LiveActivityModel(remote: app.remote)
    }

    /// 視聴状況を 2 秒ごとに取るので、番組表が応答しないときに待たされないよう短めにする
    private static func makeGuide(_ store: KeychainConnectionStore) -> MirakurunAPIClient? {
        store.guideHost.isEmpty ? nil : MirakurunAPIClient(host: store.guideHost, timeout: 3)
    }
}

#if DEBUG
extension RegzaAppContainer {
    /// 開発用: 起動引数 -InitialTab guide などで選ぶ最初のタブ
    public var sampleInitialTab: AppViewModel.Tab? { SampleData.initialTab }
}
#endif
#endif
