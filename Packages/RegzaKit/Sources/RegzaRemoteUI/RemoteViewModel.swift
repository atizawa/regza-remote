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

    private var pollingTask: Task<Void, Never>?

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
        case .failure(let error):
            lastError = error
        }
        isLiveActivityOn = LiveActivityController.isActive
    }

    // MARK: - 設定

    public func save(_ connection: RegzaConnection) async {
        RegzaRemoteService.store.save(connection)
        self.connection = connection
        nowPlaying = nil
        await RegzaRemoteService.reloadConnection()
        stopPolling()
        startPolling()
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
