import Foundation
import Observation

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴) の ViewModel (iOS と Android で共有)。
/// 配信を頼み、準備できたら再生する URL を出す (再生そのものは OS ごとの画面がする)。
/// 局を切り替えたり閉じたりしたら、前の配信を止めてチューナーを空ける
@MainActor
@Observable
public final class LivePlayerViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideUseCase
    public let stream: StreamUseCase

    public init(remote: RemoteViewModel, guide: GuideUseCase, stream: StreamUseCase, channel: RegzaChannel) {
        self.remote = remote
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
        public var channel: RegzaChannel
        public var phase: Phase
        /// 見ている局でいま放送中の番組 (番組表から)
        public var program: MirakurunProgram?
        /// 準備中に出す説明
        public var preparingMessage: String
        /// 見られる局がある放送の種類
        public var bands: [RegzaChannel.Band]
        /// 一覧に出す局 (選んでいる放送の種類のもの)
        public var channels: [Row]
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public var channel: RegzaChannel
        public var programName: String?
        /// いま見ている局
        public var isWatching: Bool
        public var id: String { channel.code }
    }

    public enum Action: Sendable {
        /// 画面を開いた。局名と番組名を出すため、チャンネルと番組表を読む
        case appear
        /// 配信を頼む
        case start
        /// 前の配信を止めて、選んだ局の配信を頼み直す
        case switchChannel(RegzaChannel)
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
        let bands = bands
        let band = remote.state.band(among: bands)
        return State(
            channel: channel,
            phase: phase,
            program: guide.currentProgram(for: channel, at: now),
            preparingMessage: "\(channel.name) の配信を準備しています…（20 秒ほど）",
            bands: bands,
            channels: watchableChannels.filter { $0.band == band }.map {
                Row(channel: $0, programName: guide.currentProgram(for: $0, at: now)?.name, isWatching: $0 == channel)
            }
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
        case .switchChannel(let newChannel):
            guard newChannel != channel else { return }
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

    // MARK: - 見られる局

    /// EPGStation で見られる局 (Mirakurun が受信している局。番組表がまだなければ CS 以外)。サブチャンネルは代表だけ
    private var watchableChannels: [RegzaChannel] {
        remote.state.channels.filter { channel in
            guard channel.isRepresentative || channel.band == .cs else { return false }
            return guide.guidePrograms.isEmpty ? channel.band != .cs : guide.guidePrograms[channel.code] != nil
        }
    }

    private var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in watchableChannels.contains { $0.band == band } }
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
            guard let row = state.channels.first(where: { $0.channel.code == code }) else {
                throw IntrospectionError.unavailable("チャンネル \(code) はライブ視聴で見られません")
            }
            send(.switchChannel(row.channel))
        case "retryAfterStoppingStalled": send(.retryAfterStoppingStalled)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
