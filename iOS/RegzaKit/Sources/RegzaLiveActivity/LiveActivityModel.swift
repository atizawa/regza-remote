#if os(iOS)
import Foundation
import Observation
import RegzaPresentation

/// ロック画面と Dynamic Island の表示 (Live Activity)。iOS だけのもの。
/// 画面と同じく RemoteViewModel の state を読み、変わったら Live Activity の表示と、閉じている間に起こしてもらう時刻を更新する
@MainActor
@Observable
public final class LiveActivityModel {
    private let remote: RemoteViewModel
    /// Live Activity を出しているか
    public private(set) var isOn = LiveActivityController.isActive
    @ObservationIgnored private var shown: RegzaActivityAttributes.ContentState?
    /// 出している途中の更新。state の変わり目と、画面のない入口の操作のあとの両方から更新するので、
    /// 1 本ずつ順に出す (重なると、古い内容の更新があとから届くことがある)
    @ObservationIgnored private var updating: Task<Void, Never>?

    public init(remote: RemoteViewModel) {
        self.remote = remote
        observe()
    }

    public func set(_ enabled: Bool) async {
        do {
            if enabled {
                // つながっていないのに「接続済み」で始めないよう、先に取り直す
                await remote.sendAndWait(.refresh)
                let state = RegzaActivityAttributes.ContentState(remote.state)
                try LiveActivityController.start(state)
                shown = state
            } else {
                await LiveActivityController.end()
            }
        } catch {
            remote.send(.report("Live Activity を開始できませんでした: \(error.localizedDescription)"))
        }
        isOn = LiveActivityController.isActive
        scheduleBackgroundRefresh()
    }

    /// いまの state を Live Activity に出し終えるまで待つ。画面のない入口 (ロック画面のボタンや閉じている間の更新) が、
    /// 操作のあと、アプリがまた止められる前に呼ぶ
    public func update() async {
        let previous = updating
        let next = Task { @MainActor in
            await previous?.value
            // 前の更新が終わってから、その時点の state を読む (待っている間に変わっても、新しいほうを出す)
            await self.show()
        }
        updating = next
        await next.value
    }

    private func show() async {
        let state = RegzaActivityAttributes.ContentState(remote.state)
        guard state != shown else { return }
        let programEndChanged = state.programEnd != shown?.programEnd
        shown = state
        await LiveActivityController.update(state)
        // ロック画面から閉じられることもあるので、出すたびに確かめる
        isOn = LiveActivityController.isActive
        // 番組の終了時刻が変わったら (選局したときなど)、起こしてもらう時刻を予約し直す
        if programEndChanged { scheduleBackgroundRefresh() }
    }

    /// Live Activity が出ていれば、閉じている間に iOS に起こしてもらう時刻を予約する
    public func scheduleBackgroundRefresh() {
        BackgroundRefresh.schedule(programEnd: RegzaActivityAttributes.ContentState(remote.state).programEnd)
    }

    /// 閉じている間に起こされたときの処理。取り直して Live Activity を更新し、次を予約する
    public func refreshInBackground() async {
        guard LiveActivityController.isActive else { return }
        await remote.sendAndWait(.refresh)
        await update()
        scheduleBackgroundRefresh()
    }

    /// state が変わるたびに Live Activity を更新する
    private func observe() {
        withObservationTracking {
            _ = remote.state
        } onChange: { [weak self] in
            // 変わる直前に呼ばれるので、変わり終わってから読む。出している間の変わり目も逃さないよう、先に見張り直す
            Task { @MainActor in
                self?.observe()
                await self?.update()
            }
        }
    }
}
#endif
