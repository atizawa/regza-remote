#if os(iOS)
import Foundation
import Observation
import RegzaApp

/// ロック画面と Dynamic Island の表示 (Live Activity) の ViewModel。iOS だけのもの。
/// RemoteViewModel がテレビとやり取りしたら、Live Activity の表示と、閉じている間に起こしてもらう時刻を更新する。
/// 後処理は Domain の型 (RegzaNowPlaying) を受け取るので、組み立て (RegzaRemoteUI) が登録し、画面は isOn と set だけを使う
@MainActor
@Observable
public final class LiveActivityModel: RemoteActivityObserver {
    private let remote: RemoteViewModel
    /// Live Activity を出しているか
    public private(set) var isOn = LiveActivityController.isActive

    public init(remote: RemoteViewModel) {
        self.remote = remote
    }

    public func set(_ enabled: Bool) async {
        do {
            if enabled {
                try await LiveActivityController.start()
                remote.send(.refresh)
            } else {
                await LiveActivityController.end()
            }
        } catch {
            remote.send(.report("Live Activity を開始できませんでした: \(error.localizedDescription)"))
        }
        isOn = LiveActivityController.isActive
        await BackgroundRefresh.schedule()
    }

    /// Live Activity が出ていれば、閉じている間に iOS に起こしてもらう時刻を予約する
    public func scheduleBackgroundRefresh() {
        Task { await BackgroundRefresh.schedule() }
    }

    public func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async {
        await RegzaRemoteService.updateLiveActivity(nowPlaying: nowPlaying, isConnected: isConnected)
        // ロック画面から閉じられることもあるので、取り直すたびに確かめる
        isOn = LiveActivityController.isActive
    }

    public func remoteViewModelDidTune(_ model: RemoteViewModel) async {
        // 番組の終了時刻が変わるので、起こしてもらう時刻を予約し直す
        await BackgroundRefresh.schedule()
    }
}
#endif
