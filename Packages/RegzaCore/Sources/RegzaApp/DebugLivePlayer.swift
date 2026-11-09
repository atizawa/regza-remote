#if DEBUG
import Foundation

extension AppViewModel {
    /// 開発用: 確かめたい EPGStation につなぐライブ視聴を作る (保存してある設定は変えない)。
    /// iOS の起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で使う
    public func debugLivePlayer(streamHost: String, channelCode: String) -> LivePlayerViewModel? {
        let json = #"[{"channel":"\#(channelCode)","name":"確認用","channel_number":1}]"#
        guard let channel = (try? JSONDecoder().decode([RegzaChannel].self, from: Data(json.utf8)))?.first else { return nil }
        // EPGStation は番組表を設定しているときだけ使うので、番組表も設定済みにしておく (番組名は出ない)
        let store = DebugStore(streamHost: streamHost)
        let guide = MirakurunGuideRepository(store: store)
        let stream = StreamUseCase(stream: EPGStationStreamRepository(store: store, guide: guide))
        return LivePlayerViewModel(remote: remote, channels: channels, guide: self.guide, stream: stream, channel: channel)
    }
}

/// 確認用のライブ視聴だけで使う、保存しない保存先
private final class DebugStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var streams: [Int] = []
    private let streamHostValue: String

    init(streamHost: String) {
        streamHostValue = streamHost
    }

    func load() -> RegzaConnection { RegzaConnection() }
    func save(_ connection: RegzaConnection) {}
    func pairingUserID() -> String { "" }

    var guideHost: String {
        get { "192.0.2.2" }
        set {}
    }

    var streamHost: String {
        get { streamHostValue }
        set {}
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { streams } }
        set { lock.withLock { streams = newValue } }
    }
}
#endif
