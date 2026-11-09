public import Foundation
public import Observation
package import RegzaDomain

/// チャンネル一覧の画面の ViewModel (iOS と Android で共有)。
/// 放送の種類ごとにチャンネルを並べ、押すとそのチャンネルに切り替える
@MainActor
@Observable
public final class ChannelListViewModel {
    public let remote: RemoteViewModel
    package let channels: any ChannelUseCaseProtocol
    package let guide: any GuideUseCaseProtocol
    package let stream: any StreamUseCaseProtocol

    package init(remote: RemoteViewModel, channels: any ChannelUseCaseProtocol, guide: any GuideUseCaseProtocol, stream: any StreamUseCaseProtocol) {
        self.remote = remote
        self.channels = channels
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
        /// 切り替え中のチャンネルのコード
        public var tuningCode: String?
        /// テレビに登録されている放送の種類 (地デジ・BS・CS の順)
        public var bands: [BroadcastBand]
        /// 出す放送の種類 (選んでいなければ、いま見ている種類)
        public var band: BroadcastBand?
        public var rows: [ChannelItem]
        /// アプリで見られる (ライブ視聴が設定されている)
        public var canStream: Bool
    }

    public enum Action: Sendable {
        /// 画面を開いた。番組名と「最初から見る」を出すため、番組表とタイムシフトの設定も読む
        case appear
        case reload
        /// 選局する (チャンネルのコード)
        case tune(String)
        /// 切り替えてから、放送中の番組を最初から再生する (チャンネルのコード)
        case tuneFromStart(String)
    }

    // 自分で持つ状態
    private var isLoading = false
    private var loadError: RegzaError?
    private var tuneError: String?
    private var tuningCode: String?
    @ObservationIgnored private let work = Work()

    /// 画面に出すもの。自分の状態と、土台・番組表・配信の状態から作る
    public var state: State {
        let bands = channels.bands
        let band = remote.band(among: bands)
        let rows = channels.items(band: band, nowPlayingCode: remote.state.nowPlaying?.channelCode)
        return State(
            isLoading: isLoading,
            loadErrorMessage: remote.channels.isEmpty ? loadError.map(Self.message) : nil,
            hasNoChannels: remote.channels.isEmpty,
            tuneError: tuneError,
            tuningCode: tuningCode,
            bands: bands,
            band: band,
            rows: rows,
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
        case .tune(let code): work.run { await self.tune(code: code, startOver: false) }
        case .tuneFromStart(let code): work.run { await self.tune(code: code, startOver: true) }
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

    private func tune(code: String, startOver: Bool) async {
        guard let channel = channels.channel(code: code) else { return }
        tuningCode = code
        defer { tuningCode = nil }
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
        case "tune": send(.tune(try row(arguments).code))
        case "tuneFromStart":
            let row = try row(arguments)
            guard row.canStartOver else { throw IntrospectionError.unavailable("\(row.name) の番組は最初から見られません") }
            send(.tuneFromStart(row.code))
        default: throw IntrospectionError.unknownAction(action)
        }
    }

    private func row(_ arguments: [String: JSONValue]) throws -> ChannelItem {
        let code = try arguments.string("channel")
        guard let row = state.rows.first(where: { $0.code == code }) else {
            throw IntrospectionError.unavailable("チャンネル \(code) は一覧にありません")
        }
        return row
    }
}
