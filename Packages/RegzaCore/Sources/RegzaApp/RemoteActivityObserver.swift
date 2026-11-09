import Foundation

/// テレビとやり取りしたあとの、OS ごとの後処理 (iOS の Live Activity とバックグラウンドの更新)。
/// Domain の型 (RegzaNowPlaying) を受け取るので、画面ではなく組み立てから登録する
@MainActor
public protocol RemoteActivityObserver: AnyObject {
    /// いま映っているものが変わった。`isConnected` は、テレビから取り直せたか
    /// (取り直せなかったときは、直前に出していたものを渡す)
    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async
    /// 選局した (番組の終了時刻が変わる)
    func remoteViewModelDidTune(_ model: RemoteViewModel) async
}

extension RemoteViewModel {
    /// 後処理を登録する。後処理は弱く持つ (後処理の側が RemoteViewModel を持っていてよい)
    public func setActivityObserver(_ observer: any RemoteActivityObserver) {
        self.observer = ActivityObserverBox(target: observer)
    }
}

/// RemoteViewModel の後処理の口 (package) を、組み立てが登録する後処理につなぐ
@MainActor
private final class ActivityObserverBox: RemoteViewModelObserver {
    weak var target: (any RemoteActivityObserver)?

    init(target: any RemoteActivityObserver) {
        self.target = target
    }

    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async {
        await target?.remoteViewModel(model, didUpdate: nowPlaying, isConnected: isConnected)
    }

    func remoteViewModelDidTune(_ model: RemoteViewModel) async {
        await target?.remoteViewModelDidTune(model)
    }
}
