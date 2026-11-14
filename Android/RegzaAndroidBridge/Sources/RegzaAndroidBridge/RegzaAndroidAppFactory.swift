import Foundation
import RegzaApp

/// Android の通信実装を保持し、Kotlin の保存先からアプリを組み立てる。
public final class RegzaAndroidAppFactory {
    let httpTransport: any HTTPTransport

    init(transport: any HTTPTransport) {
        httpTransport = transport
    }

    public convenience init(httpClient: any RegzaAndroidHTTPClient) {
        self.init(transport: AndroidHTTPTransport(httpClient: httpClient))
    }

    public func makeApp(storage: any RegzaAndroidStorage) -> RegzaAndroidApp {
        RegzaAndroidApp(storage: storage, httpTransport: httpTransport)
    }

    /// 画面・購読・配信の後片づけを起動せず、保存済みの接続でキーを1回だけ送る。
    /// 成功なら nil、失敗なら表示用の理由を返す。非同期処理の完了まで呼び出し元が待つ。
    public func sendRemoteKey(_ key: RegzaKey, storage: any RegzaAndroidStorage) async -> String? {
        let tvUseCase = await MainActor.run {
            let managers = makeStorageManagers(storage)
            return AppFactory.makeLiveTVUseCase(
                secureStorageManager: managers.secureStorageManager,
                preferencesManager: managers.preferencesManager, transport: httpTransport)
        }
        do {
            try await tvUseCase.send(key)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// 端末内サーバーへの診断口。テストでもアプリと同じ注入済み通信を使う。
    public func networkProbe(_ address: String, _ timeout: Double) async -> String {
        guard let url = URL(string: address) else { return "error: URL が正しくありません" }
        do {
            let response = try await httpTransport.send(HTTPRequest(url: url, timeout: timeout))
            return "\(response.statusCode)\n\(String(decoding: response.body, as: UTF8.self))"
        } catch {
            return "error: \(error)"
        }
    }
}
