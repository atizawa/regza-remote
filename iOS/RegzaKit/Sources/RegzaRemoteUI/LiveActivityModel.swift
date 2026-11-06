#if os(iOS)
import Foundation
import Observation
import RegzaCore
import RegzaLiveActivity

/// ロック画面と Dynamic Island の表示 (Live Activity) の ViewModel。iOS だけのもの。
/// RemoteViewModel がテレビとやり取りしたら、Live Activity の表示と、閉じている間に起こしてもらう時刻を更新する
@MainActor
@Observable
final class LiveActivityModel: RemoteViewModelObserver {
    private let remote: RemoteViewModel
    /// Live Activity を出しているか
    private(set) var isOn = LiveActivityController.isActive

    init(remote: RemoteViewModel) {
        self.remote = remote
    }

    func set(_ enabled: Bool) async {
        do {
            if enabled {
                try await LiveActivityController.start()
                await remote.refresh()
            } else {
                await LiveActivityController.end()
            }
        } catch {
            remote.report(.network("Live Activity を開始できませんでした: \(error.localizedDescription)"))
        }
        isOn = LiveActivityController.isActive
        await BackgroundRefresh.schedule()
    }

    /// Live Activity が出ていれば、閉じている間に iOS に起こしてもらう時刻を予約する
    func scheduleBackgroundRefresh() {
        Task { await BackgroundRefresh.schedule() }
    }

    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async {
        await RegzaRemoteService.updateLiveActivity(nowPlaying: nowPlaying, isConnected: isConnected)
        // ロック画面から閉じられることもあるので、取り直すたびに確かめる
        isOn = LiveActivityController.isActive
    }

    func remoteViewModelDidTune(_ model: RemoteViewModel) async {
        // 番組の終了時刻が変わるので、起こしてもらう時刻を予約し直す
        await BackgroundRefresh.schedule()
    }
}
#endif
