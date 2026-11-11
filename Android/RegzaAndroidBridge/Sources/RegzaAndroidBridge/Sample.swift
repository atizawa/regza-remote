import Foundation
import RegzaApp
import RegzaSample

extension RegzaAndroidApp {
    /// テレビにも録画サーバーにもつながない、見本の返事 (SampleTransport) で組み立てる。
    /// 本物の Repository を使うので、返事の読み取りからアプリと同じ処理を通る (JVM で動かす Android のテストで使う)。
    /// 全体の既定の通信も見本に差し替えるので、外への通信は起きない。
    /// 保存先にテレビが登録されていなければ、見本のテレビを登録してから組み立てる。
    /// fixture (SampleFixture の JSON。空なら見本の返事だけ) で、テストごとに返事を差し替える。読めなければ nil
    public static func sample(storage: any RegzaAndroidStorage, fixture: String) -> RegzaAndroidApp? {
        guard let fixture = fixture.isEmpty ? SampleFixture() : try? SampleFixture(json: fixture) else { return nil }
        let transport = SampleTransport(fixture: fixture)
        RegzaHTTP.transport = transport
        return RegzaAndroidApp(
            app: onMainActor {
                if storage.value(forKey: AndroidStorageKey.host) == nil {
                    // CLI の --sample と同じ見本のテレビと録画サーバーを登録する
                    let connection = SampleTransport.connection
                    storage.setValue(connection.host, forKey: AndroidStorageKey.host)
                    storage.setValue(connection.user, forKey: AndroidStorageKey.user)
                    storage.setValue(connection.password, forKey: AndroidStorageKey.password)
                    storage.setValue(SampleTransport.guideHost, forKey: AndroidStorageKey.guideHost)
                    storage.setValue(SampleTransport.streamHost, forKey: AndroidStorageKey.streamHost)
                }

                let managers = makeStorageManagers(storage)
                return AppViewModel(secureStorage: managers.secureStorage, preferences: managers.preferences, transport: transport)
            })
    }
}
