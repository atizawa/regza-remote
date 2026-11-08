import Foundation

/// チャンネル: テレビに登録されているチャンネルを、放送の種類ごとに、放送中の番組名つきで並べる
@MainActor
public final class ChannelUseCase {
    private let tv: any TVRepository
    private let guide: any GuideRepository

    public init(tv: any TVRepository, guide: any GuideRepository) {
        self.tv = tv
        self.guide = guide
    }

    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    public var bands: [RegzaChannel.Band] { RegzaChannel.bands(in: tv.channels) }

    /// チャンネルの ID のチャンネル。テレビに登録されていなければ nil
    public func channel(code: String) -> RegzaChannel? {
        tv.channels.first { $0.code == code }
    }

    // MARK: - ライブ視聴 (EPGStation) で見られる局

    /// EPGStation で見られる局 (Mirakurun が受信している局。番組表がまだなければ CS 以外)。サブチャンネルは代表だけ
    private var liveChannels: [RegzaChannel] {
        tv.channels.filter { channel in
            guard channel.isRepresentative || channel.band == .cs else { return false }
            return guide.guidePrograms.isEmpty ? channel.band != .cs : guide.guidePrograms[channel.code] != nil
        }
    }

    /// ライブ視聴で見られる局がある放送の種類
    public var liveBands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in liveChannels.contains { $0.band == band } }
    }

    /// ライブ視聴の局の一覧 (UI の型)。見ている局は isNowPlaying にする
    public func liveItems(band: RegzaChannel.Band?, watchingCode: String, now: Date = Date()) -> [ChannelItem] {
        liveChannels.filter { $0.band == band }.map { channel in
            ChannelItem(
                code: channel.code,
                name: channel.name,
                numberText: channel.formattedNumber,
                programName: guide.currentProgram(for: channel, at: now)?.name,
                isNowPlaying: channel.code == watchingCode,
                hasPrograms: guide.guidePrograms[channel.code] != nil,
                canStartOver: false,
                isSubchannel: false
            )
        }
    }

    /// 一覧に出すチャンネル (UI の型)。サブチャンネルは代表と、いま映っているものだけにする
    public func items(band: RegzaChannel.Band?, nowPlayingCode: String?, now: Date = Date()) -> [ChannelItem] {
        let listed = RegzaChannel.channelList(tv.channels, in: band, nowPlayingChannelCode: nowPlayingCode) {
            guide.currentProgram(for: $0, at: now)?.name
        }
        return listed.map { channel in
            let program = guide.currentProgram(for: channel, at: now)
            return ChannelItem(
                code: channel.code,
                name: channel.name,
                numberText: channel.formattedNumber,
                programName: program?.name,
                isNowPlaying: channel.code == nowPlayingCode,
                hasPrograms: guide.hasGuide && guide.guidePrograms[channel.code] != nil,
                canStartOver: program.map { tv.canStartOver(channelCode: channel.code, programStart: $0.start) } ?? false,
                isSubchannel: !channel.isRepresentative && channel.band != .cs
            )
        }
    }
}
