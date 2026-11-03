#if os(iOS)
import ActivityKit
import BackgroundTasks
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

    public static func tune(to channel: RegzaChannel) async throws {
        try await remote.tune(to: channel)
        try? await Task.sleep(for: .milliseconds(400))
        _ = await refresh()
        // 番組の終了時刻が変わるので、起こしてもらう時刻を予約し直す
        await BackgroundRefresh.schedule()
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
        ActivityContent(state: state, staleDate: staleDate(for: state))
    }

    /// 表示が古くなる時刻。システムはこの時刻に stale として描き直すので、アプリが止まっていても切り替わる。
    /// 放送は番組の終了時刻 (「番組が終わりました」に切り替える)、それ以外は 5 分後
    static func staleDate(for state: RegzaActivityAttributes.ContentState, now: Date = Date()) -> Date {
        if state.isConnected, let end = state.programEnd, end > now { return end }
        return now.addingTimeInterval(5 * 60)
    }
}

/// アプリが閉じている間に、iOS に起こしてもらって Live Activity を更新する (BGAppRefreshTask)。
/// いつ起こされるかはシステムが決めるので、番組の終了時刻ちょうどに更新されるとは限らない
public enum BackgroundRefresh {
    /// Info.plist の BGTaskSchedulerPermittedIdentifiers と同じ値
    public static var identifier: String { (Bundle.main.bundleIdentifier ?? "RegzaRemote") + ".refresh" }

    /// 起こされたときの処理。状態を取り直して Live Activity を更新し、次を予約する
    public static func run() async {
        guard LiveActivityController.isActive else { return }
        _ = await RegzaRemoteService.refresh()
        await schedule()
    }

    /// Live Activity が出ていれば、次に起こしてもらう時刻を予約する
    public static func schedule() async {
        guard LiveActivityController.isActive else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = await earliestBeginDate()
        try? BGTaskScheduler.shared.submit(request)
    }

    /// 放送中なら番組が切り替わった直後、それ以外は 15 分後 (システムが許す最短の目安)
    static func earliestBeginDate(now: Date = Date()) async -> Date {
        if let end = await RegzaRemoteService.remote.nowPlaying?.programEnd, end > now {
            return end.addingTimeInterval(30)
        }
        return now.addingTimeInterval(15 * 60)
    }
}
#endif
