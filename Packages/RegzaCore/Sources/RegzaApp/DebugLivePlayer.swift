#if DEBUG
import Foundation

extension AppViewModel {
    /// 開発用: 確かめたい EPGStation につなぐライブ視聴を作る (保存してある設定は変えない)。
    /// iOS の起動引数 -LiveHost <EPGStation> -LiveChannel <チャンネルの ID> で使う
    public func debugLivePlayer(streamHost: String, channelCode: String) -> LivePlayerViewModel? {
        let json = #"[{"channel":"\#(channelCode)","name":"確認用","channel_number":1}]"#
        guard let channel = (try? JSONDecoder().decode([ChannelData].self, from: Data(json.utf8)))?.first else { return nil }
        // EPGStation は番組表を設定しているときだけ使うので、番組表も設定済みにしておく (番組名は出ない)
        let preferencesManager = PreferencesManager(
            storage: MemoryPreferencesStorage(values: [
                .guideHost: "192.0.2.2", .streamHost: streamHost,
            ]))
        let guideRepository = MirakurunGuideRepository(
            preferencesManager: preferencesManager, mirakurunAPIClient: MirakurunAPIClient(host: "192.0.2.2"))
        let repository = EPGStationStreamRepository(
            preferencesManager: preferencesManager, epgStationAPIClient: EPGStationAPIClient(host: streamHost))
        let streamUseCase = StreamUseCase(streamRepository: repository, guideRepository: guideRepository)
        return LivePlayerViewModel(
            remoteViewModel: remoteViewModel, channelUseCase: channelUseCase, guideUseCase: self.guideUseCase, streamUseCase: streamUseCase,
            channel: UseCaseModelMapper.channel(channel))
    }
}

#endif
