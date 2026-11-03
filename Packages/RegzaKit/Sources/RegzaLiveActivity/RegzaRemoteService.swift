#if os(iOS)
import ActivityKit
import Foundation
import RegzaAppleStorage
import RegzaCore

/// アプリと Live Activity のボタン (App Intents) で共有するリモコン。
/// 操作のたびに Live Activity の表示も更新する。
public enum RegzaRemoteService {
    public static let store = KeychainConnectionStore()
    public static let remote = RegzaRemote(connection: store.load())

    public static func reloadConnection() async {
        await remote.update(connection: store.load())
    }

    public static func send(_ key: RegzaKey) async throws {
        try await remote.send(key)
        // テレビ側の状態が変わるのを少し待ってから反映する
        try? await Task.sleep(for: .milliseconds(400))
        _ = await refresh()
    }

    public static func seek(to seconds: Int) async throws {
        try await remote.seek(to: seconds)
        _ = await refresh()
    }

    /// 状態を取得して Live Activity に反映する
    public static func refresh() async -> Result<RegzaNowPlaying, RegzaError> {
        let result: Result<RegzaNowPlaying, RegzaError>
        do {
            result = .success(try await remote.refresh())
        } catch let error as RegzaError {
            result = .failure(error)
        } catch {
            result = .failure(.network(error.localizedDescription))
        }
        // 一時的な失敗で番組情報が消えないよう、失敗したときは直前の情報を「接続できません」付きで出す
        let previous = await remote.nowPlaying
        let state = RegzaActivityAttributes.ContentState(
            nowPlaying: (try? result.get()) ?? previous,
            lastCommand: await remote.lastCommand,
            isConnected: (try? result.get()) != nil
        )
        await LiveActivityController.update(state)
        return result
    }
}

/// Live Activity の開始・更新・終了
public enum LiveActivityController {
    public static var isActive: Bool {
        !Activity<RegzaActivityAttributes>.activities.isEmpty
    }

    public static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    public static func start(tvName: String = "REGZA") async throws {
        guard !isActive else { return }
        // つながっていないのに「接続済み」で始めないよう、先に状態を取得する
        let remote = RegzaRemoteService.remote
        let current = try? await remote.refresh()
        let previous = await remote.nowPlaying
        let state = RegzaActivityAttributes.ContentState(
            nowPlaying: current ?? previous,
            lastCommand: nil,
            isConnected: current != nil
        )
        _ = try Activity.request(
            attributes: RegzaActivityAttributes(tvName: tvName),
            content: content(for: state)
        )
    }

    public static func update(_ state: RegzaActivityAttributes.ContentState) async {
        for activity in Activity<RegzaActivityAttributes>.activities {
            await activity.update(content(for: state))
        }
    }

    public static func end() async {
        for activity in Activity<RegzaActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func content(
        for state: RegzaActivityAttributes.ContentState
    ) -> ActivityContent<RegzaActivityAttributes.ContentState> {
        // アプリがバックグラウンドに入ると更新が止まるので、古くなったら stale 表示にする
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(5 * 60))
    }
}
#endif
