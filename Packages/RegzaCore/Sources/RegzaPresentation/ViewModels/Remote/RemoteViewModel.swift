public import Foundation
public import Observation
package import RegzaDomain

/// OS ごとの後処理 (iOS は Live Activity とバックグラウンドの更新)。RemoteViewModel がテレビとやり取りしたあとに呼ぶ。
/// Domain の型を受け取るので、画面ではなく組み立て (RegzaApp) から登録する
@MainActor
package protocol RemoteViewModelObserver: AnyObject {
    /// いま映っているものが変わった。`isConnected` は、テレビから取り直せたか
    /// (取り直せなかったときは、直前に出していたものを渡す)
    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async
    /// 選局した (番組の終了時刻が変わる)
    func remoteViewModelDidTune(_ model: RemoteViewModel) async
}

/// アプリ全体で 1 つの ViewModel。
/// テレビへの接続・いま映っているもの・リモコンの操作・チャンネルと選局を受け持つ。
/// 画面は `state` を読み、`send` で操作する。番組表や録画などのほかの ViewModel は、結果を待てる関数 (internal) も使う
@MainActor
@Observable
public final class RemoteViewModel {
    /// テレビの操作。接続とチャンネルは、この先の Repository が持つ
    package let tv: any TVUseCaseProtocol
    /// 後処理。組み立て (RegzaApp) が、OS ごとの後処理につなぐ入れ物を入れる
    @ObservationIgnored package var observer: (any RemoteViewModelObserver)?

    /// 画面に出すもの
    public typealias State = RemoteState

    /// 画面からの操作
    public typealias Action = RemoteAction

    private var nowPlaying: RegzaNowPlaying?
    /// テレビに接続できなかった理由 (ほかの ViewModel とテストが読む。画面は state.errorMessage を読む)
    package private(set) var lastError: RegzaError?
    private var tapCount = 0
    private var isSearchingTV = false
    private var selectedBand: BroadcastBand?

    public var state: State {
        State(
            isConfigured: tv.connection.isConfigured,
            nowPlaying: nowPlaying.map(tv.item),
            errorMessage: lastError?.localizedDescription,
            tapCount: tapCount,
            isSearchingTV: isSearchingTV,
            isSampleMode: tv.isSample,
            selectedBand: selectedBand,
            nowPlayingBand: nowPlayingChannel?.band
        )
    }

    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearch: Date?
    @ObservationIgnored private let work = Work()
    /// テレビの電源が切れているだけのこともあるので、探し直す間隔を空ける
    private static let searchInterval: TimeInterval = 180

    /// - Parameter nowPlaying: 最初に出しておく「いま映っているもの」(見本など)
    package init(tv: any TVUseCaseProtocol, nowPlaying: RegzaNowPlaying? = nil) {
        self.tv = tv
        self.nowPlaying = nowPlaying
    }

    public func send(_ action: Action) {
        switch action {
        case .press(let key): press(key)
        case .seek(let seconds): run { await self.seek(to: seconds) }
        case .selectBand(let band): if selectedBand != band { selectedBand = band }
        case .loadChannels(let force): run { try? await self.loadChannels(force: force) }
        case .tune(let code):
            guard let channel = channels.first(where: { $0.code == code }) else { return }
            run { try? await self.tune(to: channel) }
        case .refresh: run { await self.refresh() }
        case .startPolling: startPolling()
        case .stopPolling: stopPolling()
        case .report(let message): lastError = .network(message)
        }
    }

    /// 操作から始める処理。終わるまで isBusy にする
    private func run(_ operation: @escaping @MainActor () async -> Void) {
        work.run(operation)
    }

    // MARK: - リモコン

    private func press(_ key: RegzaKey) {
        tapCount += 1
        guard !tv.isSample else { return }
        run {
            do {
                try await self.tv.send(key)
                // テレビ側の状態が変わるのを少し待ってから反映する
                try? await Task.sleep(for: .milliseconds(400))
                _ = await self.fetch()
                self.lastError = nil
                self.nowPlaying = await self.tv.lastNowPlaying()
            } catch {
                self.lastError = RegzaError(error)
            }
        }
    }

    private func seek(to seconds: Int) async {
        do {
            try await tv.seek(to: seconds)
            _ = await fetch()
            nowPlaying = await tv.lastNowPlaying()
        } catch {
            lastError = error
        }
    }

    // MARK: - チャンネル (ほかの ViewModel も結果を待って使う)

    /// チャンネル一覧を取得する。チャンネルの登録はあまり変わらないので、取得済みなら使い回す
    func loadChannels(force: Bool = false) async throws(RegzaError) {
        guard !tv.isSample else { return }
        try await tv.loadChannels(force: force)
    }

    func tune(to channel: RegzaChannel) async throws(RegzaError) {
        tapCount += 1
        // 切り替えの最中はテレビに問い合わせないので、取り直さずに、選んだチャンネルに切り替わったものとして出す。
        // 番組名などは定期の取得で落ち着いてから反映する
        tuned(try await tv.tune(to: channel))
        await notifyTuned()
    }

    /// いま映っている番組を最初から再生する
    func startOver() async throws(RegzaError) {
        try await tv.startOver()
    }

    /// チャンネルを切り替えてから、その番組を最初から再生する
    func tuneAndStartOver(_ channel: RegzaChannel) async throws(RegzaError) {
        tapCount += 1
        tuned(try await tv.tuneAndStartOver(channel))
        await notifyTuned()
    }

    private func tuned(_ nowPlaying: RegzaNowPlaying?) {
        lastError = nil
        self.nowPlaying = nowPlaying
    }

    private func notifyTuned() async {
        await observer?.remoteViewModel(self, didUpdate: nowPlaying, isConnected: true)
        await observer?.remoteViewModelDidTune(self)
    }

    // MARK: - 状態の定期取得

    private func startPolling(interval: Duration = .seconds(2)) {
        guard pollingTask == nil, tv.connection.isConfigured, !tv.isSample else { return }
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
            nowPlaying = value
            lastError = nil
            lastSearch = nil
        case .failure(let error):
            lastError = error
            if case .network = error { await searchForMovedTV() }
        }
    }

    /// テレビから取り直し、後処理に知らせる。
    /// 一時的な失敗で番組情報が消えないよう、失敗したときは直前の情報を「接続できません」として知らせる
    private func fetch() async -> Result<RegzaNowPlaying, RegzaError> {
        let result: Result<RegzaNowPlaying, RegzaError>
        do {
            result = .success(try await tv.refresh())
        } catch {
            result = .failure(error)
        }
        let previous = await tv.lastNowPlaying()
        await observer?.remoteViewModel(self, didUpdate: (try? result.get()) ?? previous, isConnected: (try? result.get()) != nil)
        return result
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかればそのアドレスに切り替える
    private func searchForMovedTV() async {
        if let lastSearch, Date().timeIntervalSince(lastSearch) < Self.searchInterval { return }
        lastSearch = Date()
        isSearchingTV = true
        defer { isSearchingTV = false }
        guard await tv.locateMovedTV() != nil else { return }
        await refresh()
    }

    // MARK: - 設定 (設定の ViewModel から使う)

    func save(_ connection: RegzaConnection) async {
        await tv.save(connection)
        nowPlaying = nil
        lastSearch = nil
        stopPolling()
        startPolling()
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    func pairingUserID() -> String {
        tv.pairingUserID()
    }

    /// 保存前の接続情報で視聴状況を取得してみる
    func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        await tv.testConnection(connection)
    }

    // MARK: - ほかの ViewModel が読むもの (画面は state を読む)

    package var connection: RegzaConnection { tv.connection }
    /// テレビに登録されているチャンネル。取得前は空
    package var channels: [RegzaChannel] { tv.channels }
    var isSampleMode: Bool { tv.isSample }

    /// いま映っている放送のチャンネル
    package var nowPlayingChannel: RegzaChannel? {
        guard let code = nowPlaying?.channelCode, !code.isEmpty else { return nil }
        return channels.first { $0.code == code }
    }

    /// 放送の種類を選んでいなければ、いま見ている放送の種類、それもなければ一覧の最初のものにする
    package func band(among bands: [BroadcastBand]) -> BroadcastBand? {
        .preferred(among: bands, selected: selectedBand, nowPlaying: nowPlayingChannel?.band)
    }
}

// MARK: - Introspection

extension RemoteViewModel: IntrospectableActions {
    public var introspectionName: String { "remote" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("press", "リモコンのボタンを押す", parameters: ["key": RegzaKey.allCases.map { "\($0)" }.joined(separator: " | ")]),
            ActionDescription("seek", "録画の再生位置を移す", parameters: ["seconds": "秒"]),
            ActionDescription("selectBand", "放送の種類を選ぶ (省くと選ばない)", parameters: ["band": BroadcastBand.allCases.map(\.rawValue).joined(separator: " | ")]),
            ActionDescription("loadChannels", "チャンネル一覧を読む", parameters: ["force": "true なら読み直す"]),
            ActionDescription("tune", "選局する", parameters: ["channel": "チャンネルの code"]),
            ActionDescription("refresh", "いま映っているものを取り直す"),
            ActionDescription("startPolling", "2 秒ごとに取り直す"),
            ActionDescription("stopPolling", "取り直しをやめる"),
        ]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "press":
            let name = try arguments.string("key")
            guard let key = RegzaKey.allCases.first(where: { "\($0)" == name }) else { throw IntrospectionError.invalidArgument("key") }
            return .press(key)
        case "seek": return .seek(try arguments.int("seconds"))
        case "selectBand":
            guard arguments["band"] != nil else { return .selectBand(nil) }
            guard let band = BroadcastBand(rawValue: try arguments.string("band")) else { throw IntrospectionError.invalidArgument("band") }
            return .selectBand(band)
        case "loadChannels": return .loadChannels(force: try arguments.bool("force"))
        case "tune":
            let code = try arguments.string("channel")
            guard channels.contains(where: { $0.code == code }) else {
                throw IntrospectionError.unavailable("チャンネル \(code) はテレビに登録されていません")
            }
            return .tune(code)
        case "refresh": return .refresh
        case "startPolling": return .startPolling
        case "stopPolling": return .stopPolling
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
