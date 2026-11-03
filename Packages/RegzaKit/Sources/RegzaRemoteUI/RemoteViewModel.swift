#if os(iOS)
import Foundation
import Observation
import RegzaCore
import RegzaLiveActivity

@MainActor
@Observable
public final class RemoteViewModel {
    public private(set) var connection: RegzaConnection
    public private(set) var nowPlaying: RegzaNowPlaying?
    public private(set) var lastError: RegzaError?
    public private(set) var isLiveActivityOn: Bool
    /// ボタンを押したときの触覚フィードバック用
    public private(set) var tapCount = 0
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public private(set) var isSearchingTV = false

    private var pollingTask: Task<Void, Never>?
    private var lastSearch: Date?
    /// テレビの電源が切れているだけのこともあるので、探し直す間隔を空ける
    private static let searchInterval: TimeInterval = 180

    public init() {
        connection = RegzaRemoteService.store.load()
        isLiveActivityOn = LiveActivityController.isActive
    }

    // MARK: - リモコン

    public func send(_ key: RegzaKey) {
        tapCount += 1
        Task {
            do {
                try await RegzaRemoteService.send(key)
                lastError = nil
                nowPlaying = await RegzaRemoteService.remote.nowPlaying
            } catch let error as RegzaError {
                lastError = error
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }
    }

    public func seek(to seconds: Int) {
        Task {
            do {
                try await RegzaRemoteService.seek(to: seconds)
                nowPlaying = await RegzaRemoteService.remote.nowPlaying
            } catch let error as RegzaError {
                lastError = error
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }
    }

    // MARK: - 状態の定期取得

    public func startPolling(interval: Duration = .seconds(2)) {
        guard pollingTask == nil, connection.isConfigured else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
        switch await RegzaRemoteService.refresh() {
        case .success(let value):
            nowPlaying = value
            lastError = nil
            lastSearch = nil
        case .failure(let error):
            lastError = error
            if case .network = error { await searchForMovedTV() }
        }
        isLiveActivityOn = LiveActivityController.isActive
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかればそのアドレスに切り替える
    private func searchForMovedTV() async {
        if let lastSearch, Date().timeIntervalSince(lastSearch) < Self.searchInterval { return }
        lastSearch = Date()
        isSearchingTV = true
        defer { isSearchingTV = false }
        let original = connection
        guard let host = await RegzaDiscovery.locate(original),
              // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
              !Task.isCancelled, connection == original
        else { return }
        var moved = original
        moved.host = host
        RegzaRemoteService.store.save(moved)
        connection = moved
        await RegzaRemoteService.reloadConnection()
        await refresh()
    }

    // MARK: - 設定

    public func save(_ connection: RegzaConnection) async {
        RegzaRemoteService.store.save(connection)
        self.connection = connection
        nowPlaying = nil
        lastSearch = nil
        await RegzaRemoteService.reloadConnection()
        stopPolling()
        startPolling()
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    public func pairingUserID() -> String {
        RegzaRemoteService.store.pairingUserID()
    }

    /// 保存前の接続情報で status.htm を取得してみる
    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaStatus, RegzaError> {
        do {
            return .success(try await RegzaClient(connection: connection).status())
        } catch let error as RegzaError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    // MARK: - Live Activity

    public func setLiveActivity(_ enabled: Bool) async {
        do {
            if enabled {
                try await LiveActivityController.start()
                await refresh()
            } else {
                await LiveActivityController.end()
            }
        } catch {
            lastError = .network("Live Activity を開始できませんでした: \(error.localizedDescription)")
        }
        isLiveActivityOn = LiveActivityController.isActive
    }
}
#endif
