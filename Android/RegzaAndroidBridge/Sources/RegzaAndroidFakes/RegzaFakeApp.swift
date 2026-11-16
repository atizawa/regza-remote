import Foundation
import RegzaAndroidBridge
import RegzaApp
import RegzaFakeServers

/// 偽物のテレビ・録画サーバー (RegzaFakeServers) で組み立てる入口。本物の Repository を使うので、返事の読み取りからアプリと同じ処理を通る。
/// 保存先はプロセスの中だけに置き、外への通信は起きない (プレビューと、JVM・端末のテストで使う)
public enum RegzaFakeApp {
    /// scenario は FakeScenario の JSON (空なら standard)。読めなければ nil
    public static func make(scenario: String) -> RegzaAndroidApp? {
        guard let scenario = scenario.isEmpty ? FakeScenario.standard : try? FakeScenario(json: scenario) else { return nil }
        return RegzaAndroidApp(appViewModel: onMainActor { FakeApp.makeAppViewModel(scenario: scenario) })
    }
}
