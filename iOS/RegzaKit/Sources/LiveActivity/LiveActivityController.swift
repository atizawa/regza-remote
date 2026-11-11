#if os(iOS)
import ActivityKit
import BackgroundTasks
import Foundation
import RegzaPresentation

/// Live Activity の開始・更新・終了
public enum LiveActivityController {
    public static var isActive: Bool {
        !Activity<RegzaActivityAttributes>.activities.isEmpty
    }

    public static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(_ state: RegzaActivityAttributes.ContentState, tvName: String = "REGZA") throws {
        guard !isActive else { return }
        _ = try Activity.request(
            attributes: RegzaActivityAttributes(tvName: tvName),
            content: content(for: state)
        )
    }

    static func update(_ state: RegzaActivityAttributes.ContentState) async {
        for activity in Activity<RegzaActivityAttributes>.activities {
            await activity.update(content(for: state))
        }
    }

    static func end() async {
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

    /// Live Activity が出ていれば、次に起こしてもらう時刻を予約する
    static func schedule(programEnd: Date?) {
        guard LiveActivityController.isActive else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate(programEnd: programEnd)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// 放送中なら番組が切り替わった直後、それ以外は 15 分後 (システムが許す最短の目安)
    static func earliestBeginDate(programEnd: Date?, now: Date = Date()) -> Date {
        if let programEnd, programEnd > now {
            return programEnd.addingTimeInterval(30)
        }
        return now.addingTimeInterval(15 * 60)
    }
}
#endif
