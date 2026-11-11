public import Foundation
public import Observation
package import RegzaDomain

/// EPGStation のライブ配信をアプリで見る画面 (ライブ視聴) の ViewModel。
/// 配信を頼み、準備できたら再生する URL を出す (再生そのものは OS ごとの画面がする)。
/// 局を切り替えたり閉じたりしたら、前の配信を止めてチューナーを空ける
@MainActor
@Observable
public final class LivePlayerViewModel {
    public let remoteViewModel: RemoteViewModel
    package let channelUseCase: any ChannelUseCaseProtocol
    package let guideUseCase: any GuideUseCaseProtocol
    package let streamUseCase: any StreamUseCaseProtocol

    package init(
        remoteViewModel: RemoteViewModel, channelUseCase: any ChannelUseCaseProtocol, guideUseCase: any GuideUseCaseProtocol,
        streamUseCase: any StreamUseCaseProtocol,
        channel: ChannelItem
    ) {
        self.remoteViewModel = remoteViewModel
        self.channelUseCase = channelUseCase
        self.guideUseCase = guideUseCase
        self.streamUseCase = streamUseCase
        self.channel = channel
    }

    /// 配信の段階
    public typealias Phase = LivePlayerPhase

    /// 画面に出すもの
    public typealias State = LivePlayerState

    /// 画面からの操作
    public typealias Action = LivePlayerAction

    private var channel: ChannelItem
    private var phase = Phase.preparing
    @ObservationIgnored private var streamID: Int?
    /// 配信を頼んでから見終わるまでの処理 (局を切り替えたら止めて頼み直す)
    @ObservationIgnored private var session: Task<Void, Never>?
    @ObservationIgnored private let work = Work()

    public var state: State {
        let now = Date()
        let bands = channelUseCase.liveBands
        let band = remoteViewModel.band(among: bands)
        return State(
            channelCode: channel.code,
            channelName: channel.name,
            phase: phase,
            program: guideUseCase.currentProgram(for: channel, at: now).map { guideUseCase.item($0, now: now) },
            preparingMessage: "\(channel.name) の配信を準備しています…（20 秒ほど）",
            bands: bands,
            band: band,
            channels: channelUseCase.liveItems(band: band, watchingCode: channel.code, now: now)
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                try? await self.remoteViewModel.loadChannels()
                await self.guideUseCase.loadGuidePrograms()
            }
        case .start:
            start()
        case .switchChannel(let code):
            guard code != channel.code, let newChannel = channelUseCase.channel(code: code) else { return }
            end()
            channel = newChannel
            start()
        case .retryAfterStoppingStalled:
            work.run {
                await self.streamUseCase.stopStalled()
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
            let streamUseCase = streamUseCase
            Task { await streamUseCase.stop(streamID: streamID) }
        }
    }

    private func run(_ channel: ChannelItem) async {
        phase = .preparing
        guard streamUseCase.isPlayable(channelCode: channel.code) else {
            phase = .failed(message: "このチャンネルは EPGStation で見られません。", canRetry: false)
            return
        }
        var requested: Int?
        do {
            // 前に止められずに残った、このアプリの配信は、頼む前に止める (StreamUseCase)
            let streamID = try await streamUseCase.startLiveStream(channelCode: channel.code)
            requested = streamID
            self.streamID = streamID
            let url = try await streamUseCase.waitUntilReady(streamID: streamID)
            try Task.checkCancellation()
            phase = .ready(url: url)
            // 見ていることを知らせ続ける (知らせないと EPGStation が配信を止める)
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(10))
                await streamUseCase.keep(streamID: streamID)
            }
        } catch {
            // 局を切り替えたり閉じたりして止めた (Repository は取り消しも RegzaError にして返す)
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            // 始まらなかった配信は残さない
            if let requested, streamID == requested {
                self.streamID = nil
                await streamUseCase.stop(streamID: requested)
            }
            phase = .failed(
                message: """
                    再生できませんでした。\(error.localizedDescription)
                    EPGStation で同時に変換できる数の上限に達していると始まりません。ほかの画面で見ている配信を閉じるか、準備できないまま残っている配信を止めてから試してください。
                    """, canRetry: true)
        }
    }
}

extension LivePlayerViewModel: IntrospectableActions {
    public var introspectionName: String { "player" }
    /// 配信の準備中も忙しいとする (CLI の do で、再生できるか失敗するまで待てるように)
    public var isBusy: Bool { work.isBusy || (session != nil && phase == .preparing) }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "画面を開いた。局名と番組名を出すため、チャンネルと番組表を読む"),
            ActionDescription("start", "配信を頼む (準備できたら再生する URL が出る)"),
            ActionDescription("switchChannel", "局を切り替える", parameters: ["channel": "channels の局の code"]),
            ActionDescription("retryAfterStoppingStalled", "準備できないまま残っている配信を止めて、もう一度頼む"),
            ActionDescription("end", "見終わった。配信を止めてチューナーを空ける (画面は閉じない。閉じるのは app の closePlayer)"),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "appear": return .appear
        case "start": return .start
        case "switchChannel":
            let code = try arguments.string("channel")
            guard state.channels.contains(where: { $0.code == code }) else {
                throw IntrospectionError.unavailable("チャンネル \(code) はライブ視聴で見られません")
            }
            return .switchChannel(code)
        case "retryAfterStoppingStalled": return .retryAfterStoppingStalled
        case "end": return .end
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
