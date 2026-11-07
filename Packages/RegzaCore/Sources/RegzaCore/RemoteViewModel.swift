import Foundation
import Observation

/// OS ごとの後処理 (iOS は Live Activity とバックグラウンドの更新)。RemoteViewModel がテレビとやり取りしたあとに呼ぶ
@MainActor
public protocol RemoteViewModelObserver: AnyObject {
    /// いま映っているものが変わった。`isConnected` は、テレビから取り直せたか
    /// (取り直せなかったときは、直前に出していたものを渡す)
    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async
    /// 選局した (番組の終了時刻が変わる)
    func remoteViewModelDidTune(_ model: RemoteViewModel) async
}

/// アプリ全体で 1 つの ViewModel (iOS と Android で共有)。
/// テレビへの接続・いま映っているもの・リモコンの操作・チャンネルと選局を受け持つ。
/// 画面は `state` を読み、`send` で操作する。番組表や録画などのほかの ViewModel は、結果を待てる関数 (internal) も使う
@MainActor
@Observable
public final class RemoteViewModel {
    public let store: any RegzaConnectionStore
    /// テレビのリモコン。iOS は Live Activity のボタン (App Intents) と同じものを使う
    public let remote: RegzaRemote
    @ObservationIgnored public weak var observer: (any RemoteViewModelObserver)?

    public struct State: Equatable, Sendable {
        public var connection: RegzaConnection
        public var nowPlaying: RegzaNowPlaying?
        public var lastError: RegzaError?
        /// ボタンを押した回数 (触覚フィードバックの合図)
        public var tapCount = 0
        /// つながらないので、IP アドレスが変わっていないかテレビを探している
        public var isSearchingTV = false
        /// 開発用の見本データを表示している (テレビにはつながない)
        public var isSampleMode = false
        /// 番組表とチャンネル一覧で選んでいる放送の種類 (地デジ・BS・CS)。タブを行き来しても同じものを出す。未選択なら nil
        public var selectedBand: RegzaChannel.Band?
        /// テレビに登録されているチャンネル。取得前は空
        public var channels: [RegzaChannel] = []

        /// いま映っている放送のチャンネル
        public var nowPlayingChannel: RegzaChannel? {
            guard let code = nowPlaying?.channelCode, !code.isEmpty else { return nil }
            return channels.first { $0.code == code }
        }

        /// 放送の種類を選んでいなければ、いま見ている放送の種類、それもなければ一覧の最初のものにする
        public func band(among bands: [RegzaChannel.Band]) -> RegzaChannel.Band? {
            .preferred(among: bands, selected: selectedBand, nowPlaying: nowPlayingChannel?.band)
        }
    }

    public enum Action: Sendable {
        /// リモコンのボタンを押す
        case press(RegzaKey)
        /// 録画の再生位置を移す (秒)
        case seek(Int)
        case selectBand(RegzaChannel.Band?)
        case loadChannels(force: Bool)
        case tune(RegzaChannel)
        /// いま映っているものを取り直す
        case refresh
        /// 画面が見えている間、2 秒ごとに取り直す
        case startPolling
        case stopPolling
        /// テレビとのやり取りの外で起きたエラーを出す (iOS の Live Activity を始められなかったときなど)
        case report(RegzaError)
    }

    public private(set) var state: State

    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearch: Date?
    @ObservationIgnored private let work = Work()
    /// テレビの電源が切れているだけのこともあるので、探し直す間隔を空ける
    private static let searchInterval: TimeInterval = 180

    /// - Parameter remote: 渡さなければ、保存されている接続と番組表のアドレスで作る
    public init(store: any RegzaConnectionStore, remote: RegzaRemote? = nil) {
        self.store = store
        let connection = store.load()
        state = State(connection: connection)
        self.remote = remote ?? RegzaRemote(connection: connection, guide: Self.makeGuide(host: store.guideHost))
    }

    /// 開発用の見本データを出す (テレビにはつながない)
    public func showSample(connection: RegzaConnection, nowPlaying: RegzaNowPlaying?, channels: [RegzaChannel]) {
        state.isSampleMode = true
        state.connection = connection
        state.nowPlaying = nowPlaying
        state.channels = channels
    }

    /// 番組名を補う番組表 (Mirakurun)。視聴状況を 2 秒ごとに取るので、応答しないときに待たされないよう短めにする
    public static func makeGuide(host: String) -> Mirakurun? {
        host.isEmpty ? nil : Mirakurun(host: host, timeout: 3)
    }

    public func send(_ action: Action) {
        switch action {
        case .press(let key): press(key)
        case .seek(let seconds): run { await self.seek(to: seconds) }
        case .selectBand(let band): if state.selectedBand != band { state.selectedBand = band }
        case .loadChannels(let force): run { try? await self.loadChannels(force: force) }
        case .tune(let channel): run { try? await self.tune(to: channel) }
        case .refresh: run { await self.refresh() }
        case .startPolling: startPolling()
        case .stopPolling: stopPolling()
        case .report(let error): state.lastError = error
        }
    }

    /// 操作から始める処理。終わるまで isBusy にする
    private func run(_ operation: @escaping @MainActor () async -> Void) {
        work.run(operation)
    }

    // MARK: - リモコン

    private func press(_ key: RegzaKey) {
        state.tapCount += 1
        guard !state.isSampleMode else { return }
        run {
            do {
                try await self.remote.send(key)
                // テレビ側の状態が変わるのを少し待ってから反映する
                try? await Task.sleep(for: .milliseconds(400))
                _ = await self.fetch()
                self.state.lastError = nil
                self.state.nowPlaying = await self.remote.nowPlaying
            } catch {
                self.state.lastError = RegzaError(error)
            }
        }
    }

    private func seek(to seconds: Int) async {
        do {
            try await remote.seek(to: seconds)
            _ = await fetch()
            state.nowPlaying = await remote.nowPlaying
        } catch {
            state.lastError = RegzaError(error)
        }
    }

    // MARK: - チャンネル (ほかの ViewModel も結果を待って使う)

    /// チャンネル一覧を取得する。チャンネルの登録はあまり変わらないので、取得済みなら使い回す
    func loadChannels(force: Bool = false) async throws(RegzaError) {
        guard !state.isSampleMode, force || state.channels.isEmpty else { return }
        do {
            state.channels = try await remote.client.channels()
        } catch {
            throw RegzaError(error)
        }
    }

    func tune(to channel: RegzaChannel) async throws(RegzaError) {
        state.tapCount += 1
        do {
            try await remote.tune(to: channel)
        } catch {
            throw RegzaError(error)
        }
        // 切り替えの最中は play/status を問い合わせない (RegzaRemote) ので、取り直さずに、
        // 選んだチャンネルに切り替わったものとして出す。番組名などは定期の取得で落ち着いてから反映する
        state.lastError = nil
        state.nowPlaying = await remote.nowPlaying
        await observer?.remoteViewModel(self, didUpdate: state.nowPlaying, isConnected: true)
        await observer?.remoteViewModelDidTune(self)
    }

    // MARK: - 状態の定期取得

    private func startPolling(interval: Duration = .seconds(2)) {
        guard pollingTask == nil, state.connection.isConfigured, !state.isSampleMode else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        switch await fetch() {
        case .success(let value):
            state.nowPlaying = value
            state.lastError = nil
            lastSearch = nil
        case .failure(let error):
            state.lastError = error
            if case .network = error { await searchForMovedTV() }
        }
    }

    /// テレビから取り直し、後処理に知らせる。
    /// 一時的な失敗で番組情報が消えないよう、失敗したときは直前の情報を「接続できません」として知らせる
    private func fetch() async -> Result<RegzaNowPlaying, RegzaError> {
        let result: Result<RegzaNowPlaying, RegzaError>
        do {
            result = .success(try await remote.refresh())
        } catch {
            result = .failure(RegzaError(error))
        }
        let previous = await remote.nowPlaying
        await observer?.remoteViewModel(self, didUpdate: (try? result.get()) ?? previous, isConnected: (try? result.get()) != nil)
        return result
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかればそのアドレスに切り替える
    private func searchForMovedTV() async {
        if let lastSearch, Date().timeIntervalSince(lastSearch) < Self.searchInterval { return }
        lastSearch = Date()
        state.isSearchingTV = true
        defer { state.isSearchingTV = false }
        let original = state.connection
        guard let host = await RegzaDiscovery.locate(original),
              // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
              !Task.isCancelled, state.connection == original
        else { return }
        var moved = original
        moved.host = host
        store.save(moved)
        state.connection = moved
        await remote.update(connection: store.load())
        await refresh()
    }

    // MARK: - 設定 (設定の ViewModel から使う)

    func save(_ connection: RegzaConnection) async {
        store.save(connection)
        state.connection = connection
        state.nowPlaying = nil
        state.channels = []
        lastSearch = nil
        await remote.update(connection: store.load())
        stopPolling()
        startPolling()
    }

    /// 番組名を補う番組表のアドレスを保存して、取り直す (GuideViewModel から呼ぶ)
    func updateGuide(host: String) async {
        store.guideHost = host
        await remote.update(guide: Self.makeGuide(host: host))
        await refresh()
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    func pairingUserID() -> String {
        store.pairingUserID()
    }

    /// 保存前の接続情報で視聴状況を取得してみる (普段と同じく v2 API を優先し、無ければ旧 API)
    func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        do {
            return .success(try await RegzaRemote(connection: connection).refresh())
        } catch {
            return .failure(RegzaError(error))
        }
    }

    // MARK: - ほかの ViewModel が読むもの (画面は state を読む)

    var connection: RegzaConnection { state.connection }
    var nowPlaying: RegzaNowPlaying? { state.nowPlaying }
    var channels: [RegzaChannel] { state.channels }
    var isSampleMode: Bool { state.isSampleMode }
    var nowPlayingChannel: RegzaChannel? { state.nowPlayingChannel }
    func band(among bands: [RegzaChannel.Band]) -> RegzaChannel.Band? { state.band(among: bands) }
}

extension RegzaError {
    /// RegzaError 以外のエラーは通信のエラーとして扱う
    init(_ error: any Error) {
        self = error as? RegzaError ?? .network(error.localizedDescription)
    }
}

// MARK: - Introspection

extension RemoteViewModel: Introspectable {
    public var introspectionName: String { "remote" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("press", "リモコンのボタンを押す", parameters: ["key": RegzaKey.allCases.map { "\($0)" }.joined(separator: " | ")]),
            ActionDescription("seek", "録画の再生位置を移す", parameters: ["seconds": "秒"]),
            ActionDescription("selectBand", "放送の種類を選ぶ (省くと選ばない)", parameters: ["band": RegzaChannel.Band.allCases.map(\.rawValue).joined(separator: " | ")]),
            ActionDescription("loadChannels", "チャンネル一覧を読む", parameters: ["force": "true なら読み直す"]),
            ActionDescription("tune", "選局する", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("refresh", "いま映っているものを取り直す"),
            ActionDescription("startPolling", "2 秒ごとに取り直す"),
            ActionDescription("stopPolling", "取り直しをやめる"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "press":
            let name = try arguments.string("key")
            guard let key = RegzaKey.allCases.first(where: { "\($0)" == name }) else { throw IntrospectionError.invalidArgument("key") }
            send(.press(key))
        case "seek": send(.seek(try arguments.int("seconds")))
        case "selectBand":
            guard arguments["band"] != nil else { return send(.selectBand(nil)) }
            guard let band = RegzaChannel.Band(rawValue: try arguments.string("band")) else { throw IntrospectionError.invalidArgument("band") }
            send(.selectBand(band))
        case "loadChannels": send(.loadChannels(force: try arguments.bool("force")))
        case "tune":
            let code = try arguments.string("channel")
            guard let channel = state.channels.first(where: { $0.code == code }) else {
                throw IntrospectionError.unavailable("チャンネル \(code) はテレビに登録されていません")
            }
            send(.tune(channel))
        case "refresh": send(.refresh)
        case "startPolling": send(.startPolling)
        case "stopPolling": send(.stopPolling)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
