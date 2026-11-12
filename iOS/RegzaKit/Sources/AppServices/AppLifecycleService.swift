import Foundation
import RegzaInfrastructure

/// 終了通知を受け、このアプリが開始した配信の停止を試みる。
struct AppLifecycleService: Sendable {
    let preferencesManager: PreferencesManager
    let httpTransport: any HTTPTransport
    var maximumWait: DispatchTimeInterval = .seconds(2)

    @discardableResult
    func applicationWillTerminate() -> DispatchTimeoutResult {
        let host = preferencesManager.value(forKey: .streamHost) ?? ""
        guard !host.isEmpty, !preferencesManager.integers(forKey: .ownStreamIDs).isEmpty else { return .success }

        let epgStationAPIClient = EPGStationAPIClient(host: host, transport: httpTransport)
        let semaphore = DispatchSemaphore(value: 0)
        // 終了通知の呼び出し元が MainActor で待っていても、停止処理を進められるようにする。
        Task.detached {
            await EPGStationStreamRepository.cleanUp(epgStationAPIClient, preferencesManager: preferencesManager)
            semaphore.signal()
        }
        // 停止できなかった ID は保存先に残り、次回起動時の cleanUp で回収される。
        return semaphore.wait(timeout: .now() + maximumWait)
    }
}
