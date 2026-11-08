import Foundation
import Observation

/// チャンネル一覧の画面の ViewModel (iOS と Android で共有)。
/// 放送の種類ごとにチャンネルを並べ、押すとそのチャンネルに切り替える
@MainActor
@Observable
public final class ChannelListViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideUseCase
    public let stream: StreamUseCase

    public init(remote: RemoteViewModel, guide: GuideUseCase, stream: StreamUseCase) {
        self.remote = remote
        self.guide = guide
        self.stream = stream
    }

    public struct State: Equatable, Sendable {
        public var isLoading: Bool
        /// 一覧の代わりに出す、取得できなかった説明。一覧があれば nil
        public var loadErrorMessage: String?
        /// まだ一覧がない (読み込み中か、取得できなかった)
        public var hasNoChannels: Bool
        /// 切り替えられなかったときの説明
        public var tuneError: String?
        /// 切り替え中のチャンネル
        public var tuning: RegzaChannel?
        /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
        public var bands: [RegzaChannel.Band]
        /// 出す放送の種類 (選んでいなければ、いま見ている種類)
        public var band: RegzaChannel.Band?
        public var rows: [Row]
        /// アプリで見られる (ライブ視聴が設定されている)
        public var canStream: Bool
    }

    /// 1 チャンネル分の行
    public struct Row: Equatable, Sendable, Identifiable {
        public var channel: RegzaChannel
        /// 放送中の番組名
        public var programName: String?
        public var isNowPlaying: Bool
        /// 番組表を開ける
        public var hasPrograms: Bool
        /// 放送中の番組を最初から見られる
        public var canStartOver: Bool
        /// 控えめに出す (同じ放送局のサブチャンネル。CS は局ごとに別なので控えめにしない)
        public var isSubchannel: Bool

        public var id: String { channel.code }
    }

    public enum Action: Sendable {
        /// 画面を開いた。番組名と「最初から見る」を出すため、番組表とタイムシフトの設定も読む
        case appear
        case reload
        case tune(RegzaChannel)
        /// 切り替えてから、放送中の番組を最初から再生する
        case tuneFromStart(RegzaChannel)
    }

    // 自分で持つ状態
    private var isLoading = false
    private var loadError: RegzaError?
    private var tuneError: String?
    private var tuning: RegzaChannel?
    @ObservationIgnored private let work = Work()

    /// 画面に出すもの。自分の状態と、土台・番組表・配信の状態から作る
    public var state: State {
        let channels = remote.state.channels
        let bands = RegzaChannel.bands(in: channels)
        let band = remote.state.band(among: bands)
        let nowPlayingCode = remote.state.nowPlaying?.channelCode
        let listed = RegzaChannel.channelList(channels, in: band, nowPlayingChannelCode: nowPlayingCode) {
            guide.currentProgram(for: $0)?.name
        }
        return State(
            isLoading: isLoading,
            loadErrorMessage: channels.isEmpty ? loadError.map(Self.message) : nil,
            hasNoChannels: channels.isEmpty,
            tuneError: tuneError,
            tuning: tuning,
            bands: bands,
            band: band,
            rows: listed.map { channel in
                let program = guide.currentProgram(for: channel)
                return Row(
                    channel: channel,
                    programName: program?.name,
                    isNowPlaying: channel.code == nowPlayingCode,
                    hasPrograms: guide.hasGuide && guide.guidePrograms[channel.code] != nil,
                    canStartOver: program.map { remote.tv.canStartOver(channelCode: channel.code, programStart: $0.start) } ?? false,
                    isSubchannel: !channel.isRepresentative && channel.band != .cs
                )
            },
            canStream: stream.canStream
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                await self.load(force: false)
                await self.guide.loadGuidePrograms()
                await self.remote.tv.loadTimeshiftSettings()
            }
        case .reload: work.run { await self.load(force: true) }
        case .tune(let channel): work.run { await self.tune(to: channel, startOver: false) }
        case .tuneFromStart(let channel): work.run { await self.tune(to: channel, startOver: true) }
        }
    }

    private static func message(for error: RegzaError) -> String {
        switch error {
        case .httpStatus(404), .unsupported: "この機種はチャンネル一覧の取得に対応していません。"
        default: error.localizedDescription
        }
    }

    private func load(force: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await remote.loadChannels(force: force)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    private func tune(to channel: RegzaChannel, startOver: Bool) async {
        tuning = channel
        defer { tuning = nil }
        tuneError = nil
        do {
            if !startOver {
                try await remote.tune(to: channel)
            } else if channel.code == remote.state.nowPlaying?.channelCode {
                try await remote.startOver()
            } else {
                try await remote.tuneAndStartOver(channel)
            }
        } catch .commandRejected {
            tuneError = "\(channel.name) に切り替えられませんでした。テレビの電源が入っているか確認してください。"
        } catch {
            tuneError = error.localizedDescription
        }
    }
}

extension ChannelListViewModel: Introspectable {
    public var introspectionName: String { "channelList" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "画面を開いたときと同じく読み込む"),
            ActionDescription("reload", "チャンネル一覧を読み直す"),
            ActionDescription("tune", "選局する", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("tuneFromStart", "選局して、放送中の番組を最初から再生する", parameters: ["channel": "チャンネルの code"]),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "appear": send(.appear)
        case "reload": send(.reload)
        case "tune": send(.tune(try row(arguments).channel))
        case "tuneFromStart":
            let row = try row(arguments)
            guard row.canStartOver else { throw IntrospectionError.unavailable("\(row.channel.name) の番組は最初から見られません") }
            send(.tuneFromStart(row.channel))
        default: throw IntrospectionError.unknownAction(action)
        }
    }

    private func row(_ arguments: [String: JSONValue]) throws -> Row {
        let code = try arguments.string("channel")
        guard let row = state.rows.first(where: { $0.channel.code == code }) else {
            throw IntrospectionError.unavailable("チャンネル \(code) は一覧にありません")
        }
        return row
    }
}
