import Foundation
import Observation

/// チャンネル一覧の画面の ViewModel (iOS と Android で共有)。
/// 放送の種類ごとにチャンネルを並べ、押すとそのチャンネルに切り替える
@MainActor
@Observable
public final class ChannelListViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel
    public let stream: StreamViewModel

    public init(remote: RemoteViewModel, guide: GuideViewModel, stream: StreamViewModel) {
        self.remote = remote
        self.guide = guide
        self.stream = stream
    }

    public private(set) var isLoading = false
    public private(set) var loadError: RegzaError?
    /// 切り替えられなかったときの説明
    public private(set) var tuneError: String?
    /// 切り替え中のチャンネル
    public private(set) var tuning: RegzaChannel?

    /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
    public var bands: [RegzaChannel.Band] {
        RegzaChannel.bands(in: remote.channels)
    }

    /// 出す放送の種類 (選んでいなければ、いま見ている種類)
    public var band: RegzaChannel.Band? {
        remote.band(among: bands)
    }

    /// 一覧に出すチャンネル
    public var channels: [RegzaChannel] {
        RegzaChannel.channelList(remote.channels, in: band, nowPlayingChannelCode: remote.nowPlaying?.channelCode) {
            guide.currentProgram(for: $0)?.name
        }
    }

    /// 一覧の代わりに出す、取得できなかった説明。一覧があれば nil
    public var loadErrorMessage: String? {
        guard let loadError, remote.channels.isEmpty else { return nil }
        switch loadError {
        case .httpStatus(404), .unsupported: return "この機種はチャンネル一覧の取得に対応していません。"
        default: return loadError.localizedDescription
        }
    }

    /// そのチャンネルで放送中の番組名
    public func programName(for channel: RegzaChannel) -> String? {
        guide.currentProgram(for: channel)?.name
    }

    public func isNowPlaying(_ channel: RegzaChannel) -> Bool {
        channel.code == remote.nowPlaying?.channelCode
    }

    /// そのチャンネルの番組表を出せるか
    public func hasPrograms(_ channel: RegzaChannel) -> Bool {
        guide.hasGuide && guide.guidePrograms[channel.code] != nil
    }

    public var canStream: Bool { stream.canStream }

    /// そのチャンネルの放送中の番組を最初から見られるか
    public func canStartOver(_ channel: RegzaChannel) -> Bool {
        guard let program = guide.currentProgram(for: channel) else { return false }
        return guide.canStartOver(channelCode: channel.code, programStart: program.start)
    }

    /// 画面を開いたとき。番組名と「最初から見る」を出すため、番組表とタイムシフトの設定も読む
    public func appear() async {
        await load(force: false)
        await guide.loadGuidePrograms()
        await guide.loadTimeshiftSettings()
    }

    public func load(force: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await remote.loadChannels(force: force)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    /// 切り替える。`startOver` なら、切り替えてから番組を最初から再生する
    public func tune(to channel: RegzaChannel, startOver: Bool = false) async {
        tuning = channel
        defer { tuning = nil }
        tuneError = nil
        do {
            if !startOver {
                try await remote.tune(to: channel)
            } else if isNowPlaying(channel) {
                guide.startOver()
            } else {
                try await guide.tuneAndStartOver(channel)
            }
        } catch .commandRejected {
            tuneError = "\(channel.name) に切り替えられませんでした。テレビの電源が入っているか確認してください。"
        } catch {
            tuneError = error.localizedDescription
        }
    }
}
