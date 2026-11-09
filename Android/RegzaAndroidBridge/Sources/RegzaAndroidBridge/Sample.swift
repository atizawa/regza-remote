import Foundation
import RegzaApp
import RegzaSample

extension RegzaAndroidApp {
    /// テレビにも録画サーバーにもつながない、見本の返事 (SampleTransport) で組み立てる。
    /// 本物の Repository を使うので、返事の読み取りからアプリと同じ処理を通る (JVM で動かす Android のテストで使う)。
    /// 全体の既定の通信も見本に差し替えるので、外への通信は起きない。
    /// 保存先にテレビが登録されていなければ、見本のテレビを登録してから組み立てる
    public static func sample(storage: any RegzaAndroidStorage) -> RegzaAndroidApp {
        let transport = SampleTransport()
        RegzaHTTP.transport = transport
        if storage.value(forKey: AndroidStorageKey.host) == nil {
            storage.setValue("192.0.2.10", forKey: AndroidStorageKey.host)
            storage.setValue("sample", forKey: AndroidStorageKey.user)
            storage.setValue("sample", forKey: AndroidStorageKey.password)
            storage.setValue("192.0.2.2", forKey: AndroidStorageKey.guideHost)
        }
        return RegzaAndroidApp(app: onMainActor {
            let store = AndroidConnectionStore(storage: storage)
            return AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport), transport: transport)
        })
    }
}
