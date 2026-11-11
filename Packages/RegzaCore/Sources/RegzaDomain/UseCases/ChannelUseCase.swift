import Foundation

/// チャンネル: テレビに登録されているチャンネルを、放送の種類ごとに、放送中の番組名つきで並べる
@MainActor
public protocol ChannelUseCaseProtocol: AnyObject {
    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    var bands: [BroadcastBand] { get }

    /// チャンネルの ID のチャンネル。テレビに登録されていなければ nil
    func channel(code: String) -> ChannelItem?

    /// ライブ視聴で見られる局がある放送の種類
    var liveBands: [BroadcastBand] { get }

    /// ライブ視聴の局の一覧 (UI の型)。見ている局は isNowPlaying にする
    func liveItems(band: BroadcastBand?, watchingCode: String, now: Date) -> [ChannelItem]

    /// 一覧に出すチャンネル (UI の型)。サブチャンネルは代表と、いま映っているものだけにする
    func items(band: BroadcastBand?, nowPlayingCode: String?, now: Date) -> [ChannelItem]
}

extension ChannelUseCaseProtocol {
    public func liveItems(band: BroadcastBand?, watchingCode: String) -> [ChannelItem] {
        liveItems(band: band, watchingCode: watchingCode, now: Date())
    }

    public func items(band: BroadcastBand?, nowPlayingCode: String?) -> [ChannelItem] {
        items(band: band, nowPlayingCode: nowPlayingCode, now: Date())
    }
}

/// チャンネル: テレビに登録されているチャンネルを、放送の種類ごとに、放送中の番組名つきで並べる
@MainActor
public final class ChannelUseCase: ChannelUseCaseProtocol {
    private let tvRepository: any TVRepositoryProtocol
    private let guideRepository: any GuideRepositoryProtocol

    public init(tvRepository: any TVRepositoryProtocol, guideRepository: any GuideRepositoryProtocol) {
        self.tvRepository = tvRepository
        self.guideRepository = guideRepository
    }

    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    public var bands: [BroadcastBand] { ChannelData.bands(in: tvRepository.channels) }

    /// チャンネルの ID のチャンネル。テレビに登録されていなければ nil
    public func channel(code: String) -> ChannelItem? {
        tvRepository.channels.first { $0.code == code }.map(UseCaseModelMapper.channel)
    }

    // MARK: - ライブ視聴 (EPGStation) で見られる局

    /// EPGStation で見られる局 (Mirakurun が受信している局。番組表がまだなければ CS 以外)。サブチャンネルは代表だけ
    private var liveChannels: [ChannelData] {
        tvRepository.channels.filter { channel in
            guard channel.isRepresentative || channel.band == .cs else { return false }
            return guideRepository.guidePrograms.isEmpty ? channel.band != .cs : guideRepository.guidePrograms[channel.code] != nil
        }
    }

    /// ライブ視聴で見られる局がある放送の種類
    public var liveBands: [BroadcastBand] {
        ChannelData.Band.allCases.filter { band in liveChannels.contains { $0.band == band } }
    }

    /// ライブ視聴の局の一覧 (UI の型)。見ている局は isNowPlaying にする
    public func liveItems(band: BroadcastBand?, watchingCode: String, now: Date = Date()) -> [ChannelItem] {
        liveChannels.filter { $0.band == band }.map { channel in
            ChannelItem(
                code: channel.code,
                name: channel.name,
                numberText: channel.formattedNumber,
                programName: guideRepository.currentProgram(for: channel, at: now)?.name,
                isNowPlaying: channel.code == watchingCode,
                hasPrograms: guideRepository.guidePrograms[channel.code] != nil,
                canStartOver: false,
                isSubchannel: false, band: channel.band, isRepresentative: channel.isRepresentative, remoteNumber: channel.remoteNumber
            )
        }
    }

    /// 一覧に出すチャンネル (UI の型)。サブチャンネルは代表と、いま映っているものだけにする
    public func items(band: BroadcastBand?, nowPlayingCode: String?, now: Date = Date()) -> [ChannelItem] {
        let listed = ChannelData.channelList(tvRepository.channels, in: band, nowPlayingChannelCode: nowPlayingCode) {
            guideRepository.currentProgram(for: $0, at: now)?.name
        }
        return listed.map { channel in
            let program = guideRepository.currentProgram(for: channel, at: now)
            return ChannelItem(
                code: channel.code,
                name: channel.name,
                numberText: channel.formattedNumber,
                programName: program?.name,
                isNowPlaying: channel.code == nowPlayingCode,
                hasPrograms: guideRepository.hasGuide && guideRepository.guidePrograms[channel.code] != nil,
                canStartOver: program.map { tvRepository.canStartOver(channelCode: channel.code, programStart: $0.start) } ?? false,
                isSubchannel: !channel.isRepresentative && channel.band != .cs,
                band: channel.band, isRepresentative: channel.isRepresentative, remoteNumber: channel.remoteNumber
            )
        }
    }
}
