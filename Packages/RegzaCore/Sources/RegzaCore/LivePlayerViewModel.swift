import Foundation
import Observation

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴) の ViewModel (iOS と Android で共有)。
/// 配信を頼み、準備できたら再生する URL を出す (再生そのものは OS ごとの画面がする)。
/// 局を切り替えたり閉じたりしたら、前の配信を止めてチューナーを空ける
@MainActor
@Observable
public final class LivePlayerViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel
    public let stream: StreamViewModel
    public let server: EPGStation

    public init(remote: RemoteViewModel, guide: GuideViewModel, stream: StreamViewModel, server: EPGStation, channel: RegzaChannel) {
        self.remote = remote
        self.guide = guide
        self.stream = stream
        self.server = server
        self.channel = channel
    }

    public enum Phase: Equatable, Sendable {
        case preparing
        /// 再生できる (HLS のプレイリストの URL)
        case ready(URL)
        case failed(String, canRetry: Bool)
    }

    /// いま見ている局
    public private(set) var channel: RegzaChannel
    public private(set) var phase = Phase.preparing
    @ObservationIgnored private var streamID: Int?
    /// 配信を頼んでから見終わるまでの処理 (局を切り替えたら止めて頼み直す)
    @ObservationIgnored private var session: Task<Void, Never>?

    /// 準備中に出す説明
    public var preparingMessage: String { "\(channel.name) の配信を準備しています…（20 秒ほど）" }

    // MARK: - 見られる局

    /// EPGStation で見られる局 (Mirakurun が受信している局。番組表がまだなければ CS 以外)。サブチャンネルは代表だけ
    public var watchableChannels: [RegzaChannel] {
        remote.channels.filter { channel in
            guard channel.isRepresentative || channel.band == .cs else { return false }
            return guide.guidePrograms.isEmpty ? channel.band != .cs : guide.guidePrograms[channel.code] != nil
        }
    }

    public var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in watchableChannels.contains { $0.band == band } }
    }

    /// 一覧に出す局 (選んでいる放送の種類のもの)
    public var listedChannels: [RegzaChannel] {
        let band = remote.band(among: bands)
        return watchableChannels.filter { $0.band == band }
    }

    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guide.currentProgram(for: channel, at: date)
    }

    // MARK: - 配信

    /// 画面を開いたとき。局名と番組名を出すため、チャンネルと番組表を読む
    public func appear() async {
        try? await remote.loadChannels()
        await guide.loadGuidePrograms()
    }

    public func start() {
        session?.cancel()
        let channel = channel
        session = Task { await run(channel) }
    }

    /// 前の配信を止めて、選んだ局の配信を頼み直す
    public func switchChannel(to newChannel: RegzaChannel) {
        guard newChannel != channel else { return }
        end()
        channel = newChannel
        start()
    }

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止めてから、もう一度頼む
    public func retryAfterStoppingStalled() async {
        await stream.stopStalled()
        start()
    }

    /// 見終わった。配信を止めてチューナーを空ける
    public func end() {
        session?.cancel()
        session = nil
        phase = .preparing
        if let streamID {
            self.streamID = nil
            let server = server
            Task {
                if (try? await server.stop(streamID: streamID)) != nil { stream.stopped(streamID) }
            }
        }
    }

    private func run(_ channel: RegzaChannel) async {
        phase = .preparing
        guard let channelID = EPGStation.channelID(channelCode: channel.code) else {
            phase = .failed("このチャンネルは EPGStation で見られません。", canRetry: false)
            return
        }
        var requested: Int?
        do {
            // 前に止められずに残った、このアプリの配信を先に止める
            await stream.cleanUp()
            let streamID = try await server.startLiveStream(channelID: channelID)
            requested = streamID
            self.streamID = streamID
            stream.started(streamID)
            try await server.waitUntilReady(streamID: streamID)
            guard let url = server.playlistURL(streamID: streamID) else { throw RegzaError.invalidHost }
            phase = .ready(url)
            // 見ていることを知らせ続ける (知らせないと EPGStation が配信を止める)
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(10))
                try? await server.keep(streamID: streamID)
            }
        } catch is CancellationError {
            return
        } catch {
            // 始まらなかった配信は残さない
            if let requested, streamID == requested {
                self.streamID = nil
                if (try? await server.stop(streamID: requested)) != nil { stream.stopped(requested) }
            }
            phase = .failed("""
                再生できませんでした。\(error.localizedDescription)
                EPGStation で同時に変換できる数の上限に達していると始まりません。ほかの画面で見ている配信を閉じるか、準備できないまま残っている配信を止めてから試してください。
                """, canRetry: true)
        }
    }
}

extension StreamViewModel {
    /// その局を見るライブ視聴の ViewModel。配信できないなら nil
    public func livePlayer(for channel: RegzaChannel) -> LivePlayerViewModel? {
        guard let server = streamServer() else { return nil }
        return LivePlayerViewModel(remote: remote, guide: guide, stream: self, server: server, channel: channel)
    }
}
