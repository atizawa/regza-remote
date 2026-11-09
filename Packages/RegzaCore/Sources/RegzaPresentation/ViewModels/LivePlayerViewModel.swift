public import Foundation
public import Observation
package import RegzaDomain

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴) の ViewModel (iOS と Android で共有)。
/// 配信を頼み、準備できたら再生する URL を出す (再生そのものは OS ごとの画面がする)。
/// 局を切り替えたり閉じたりしたら、前の配信を止めてチューナーを空ける
@MainActor
@Observable
public final class LivePlayerViewModel {
    public let remote: RemoteViewModel
    package let channels: any ChannelUseCaseProtocol
    package let guide: any GuideUseCaseProtocol
    package let stream: any StreamUseCaseProtocol

    package init(remote: RemoteViewModel, channels: any ChannelUseCaseProtocol, guide: any GuideUseCaseProtocol, stream: any StreamUseCaseProtocol, channel: RegzaChannel) {
        self.remote = remote
        self.channels = channels
        self.guide = guide
        self.stream = stream
        self.channel = channel
    }

    public enum Phase: Equatable, Sendable {
        case preparing
        /// 再生できる (HLS のプレイリストの URL)
        case ready(URL)
        case failed(String, canRetry: Bool)
    }

    public struct State: Equatable, Sendable {
        /// いま見ている局
        /// いま見ている局のコードと名前
        public var channelCode: String
        public var channelName: String
        public var phase: Phase
        /// 見ている局でいま放送中の番組 (番組表から)
        public var program: ProgramItem?
        /// 準備中に出す説明
        public var preparingMessage: String
        /// 見られる局がある放送の種類
        public var bands: [BroadcastBand]
        /// 選んでいる放送の種類
        public var band: BroadcastBand?
        /// 一覧に出す局 (選んでいる放送の種類のもの)
        public var channels: [ChannelItem]
    }

    public enum Action: Sendable {
        /// 画面を開いた。局名と番組名を出すため、チャンネルと番組表を読む
        case appear
        /// 配信を頼む
        case start
        /// 前の配信を止めて、選んだ局の配信を頼み直す
        case switchChannel(String)
        /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止めてから、もう一度頼む
        case retryAfterStoppingStalled
        /// 見終わった。配信を止めてチューナーを空ける
        case end
    }

    private var channel: RegzaChannel
    private var phase = Phase.preparing
    @ObservationIgnored private var streamID: Int?
    /// 配信を頼んでから見終わるまでの処理 (局を切り替えたら止めて頼み直す)
    @ObservationIgnored private var session: Task<Void, Never>?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let now = Date()
        let bands = channels.liveBands
        let band = remote.band(among: bands)
        return State(
            channelCode: channel.code,
            channelName: channel.name,
            phase: phase,
            program: guide.currentProgram(for: channel, at: now).map { guide.item($0, now: now) },
            preparingMessage: "\(channel.name) の配信を準備しています…（20 秒ほど）",
            bands: bands,
            band: band,
            channels: channels.liveItems(band: band, watchingCode: channel.code, now: now)
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                try? await self.remote.loadChannels()
                await self.guide.loadGuidePrograms()
            }
        case .start:
            start()
        case .switchChannel(let code):
            guard code != channel.code, let newChannel = channels.channel(code: code) else { return }
            end()
            channel = newChannel
            start()
        case .retryAfterStoppingStalled:
            work.run {
                await self.stream.stopStalled()
                self.start()
            }
        case .end:
            end()
        }
    }

    // MARK: - 配信

    private func start() {
        session?.cancel()
        let channel = channel
        session = Task { await run(channel) }
    }

    private func end() {
        session?.cancel()
        session = nil
        phase = .preparing
        if let streamID {
            self.streamID = nil
            let stream = stream
            Task { await stream.stop(streamID: streamID) }
        }
    }

    private func run(_ channel: RegzaChannel) async {
        phase = .preparing
        guard stream.isPlayable(channelCode: channel.code) else {
            phase = .failed("このチャンネルは EPGStation で見られません。", canRetry: false)
            return
        }
        var requested: Int?
        do {
            // 前に止められずに残った、このアプリの配信は、頼む前に止める (StreamUseCase)
            let streamID = try await stream.startLiveStream(channelCode: channel.code)
            requested = streamID
            self.streamID = streamID
            let url = try await stream.waitUntilReady(streamID: streamID)
            try Task.checkCancellation()
            phase = .ready(url)
            // 見ていることを知らせ続ける (知らせないと EPGStation が配信を止める)
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(10))
                await stream.keep(streamID: streamID)
            }
        } catch {
            // 局を切り替えたり閉じたりして止めた (Repository は取り消しも RegzaError にして返す)
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            // 始まらなかった配信は残さない
            if let requested, streamID == requested {
                self.streamID = nil
                await stream.stop(streamID: requested)
            }
            phase = .failed("""
                再生できませんでした。\(error.localizedDescription)
                EPGStation で同時に変換できる数の上限に達していると始まりません。ほかの画面で見ている配信を閉じるか、準備できないまま残っている配信を止めてから試してください。
                """, canRetry: true)
        }
    }
}

extension LivePlayerViewModel: Introspectable {
    public var introspectionName: String { "player" }
    public var introspectionValue: Any { state }
    /// 配信の準備中も忙しいとする (CLI の do で、再生できるか失敗するまで待てるように)
    public var isBusy: Bool { work.isBusy || (session != nil && phase == .preparing) }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("switchChannel", "局を切り替える", parameters: ["channel": "channels の局の code"]),
            ActionDescription("retryAfterStoppingStalled", "準備できないまま残っている配信を止めて、もう一度頼む"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "switchChannel":
            let code = try arguments.string("channel")
            guard state.channels.contains(where: { $0.code == code }) else {
                throw IntrospectionError.unavailable("チャンネル \(code) はライブ視聴で見られません")
            }
            send(.switchChannel(code))
        case "retryAfterStoppingStalled": send(.retryAfterStoppingStalled)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
