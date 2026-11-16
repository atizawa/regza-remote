import Foundation
import RegzaApp
import RegzaFakeServers

extension RegzaAndroidApp {
    /// 偽物のテレビ・録画サーバー (FakeServersTransport) で組み立てる。本物の Repository を使うので、返事の読み取りからアプリと同じ処理を通る
    /// (プレビューと、JVM で動かす Android のテストで使う)。外への通信は起きない。
    /// 保存先にテレビが登録されていなければ、場面で登録済みのものを入れてから組み立てる。
    /// scenario は FakeScenario の JSON (空なら standard)。読めなければ nil
    public static func fake(storage: any RegzaAndroidStorage, scenario: String) -> RegzaAndroidApp? {
        guard let scenario = scenario.isEmpty ? FakeScenario.standard : try? FakeScenario(json: scenario) else { return nil }
        return RegzaAndroidApp(
            appViewModel: onMainActor {
                let managers = makeStorageManagers(storage)
                if storage.value(forKey: AndroidStorageKey.host) == nil {
                    scenario.register(secureStorageManager: managers.secureStorageManager, preferencesManager: managers.preferencesManager)
                }
                return AppFactory.makeLiveAppViewModel(
                    secureStorageManager: managers.secureStorageManager, preferencesManager: managers.preferencesManager,
                    transport: FakeServersTransport(scenario: scenario))
            })
    }
}
