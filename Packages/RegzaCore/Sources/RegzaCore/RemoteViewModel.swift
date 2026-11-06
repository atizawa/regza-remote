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
/// 番組表 (GuideViewModel)・録画 (ReservationsViewModel)・配信 (StreamViewModel) はこれを参照する
@MainActor
@Observable
public final class RemoteViewModel {
    public let store: any RegzaConnectionStore
    /// テレビのリモコン。iOS は Live Activity のボタン (App Intents) と同じものを使う
    public let remote: RegzaRemote
    @ObservationIgnored public weak var observer: (any RemoteViewModelObserver)?

    public private(set) var connection: RegzaConnection
    public private(set) var nowPlaying: RegzaNowPlaying?
    public private(set) var lastError: RegzaError?
    /// ボタンを押したときの触覚フィードバック用
    public private(set) var tapCount = 0
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public private(set) var isSearchingTV = false

    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var lastSearch: Date?
    /// テレビの電源が切れているだけのこともあるので、探し直す間隔を空ける
    private static let searchInterval: TimeInterval = 180

    /// 開発用の見本データを表示している (テレビにはつながない)
    public private(set) var isSampleMode = false

    /// - Parameter remote: 渡さなければ、保存されている接続と番組表のアドレスで作る
    public init(store: any RegzaConnectionStore, remote: RegzaRemote? = nil) {
        self.store = store
        let connection = store.load()
        self.connection = connection
        self.remote = remote ?? RegzaRemote(connection: connection, guide: Self.makeGuide(host: store.guideHost))
    }

    /// 開発用の見本データを出す (テレビにはつながない)
    public func showSample(connection: RegzaConnection, nowPlaying: RegzaNowPlaying?, channels: [RegzaChannel]) {
        isSampleMode = true
        self.connection = connection
        self.nowPlaying = nowPlaying
        self.channels = channels
    }

    /// 番組名を補う番組表 (Mirakurun)。視聴状況を 2 秒ごとに取るので、応答しないときに待たされないよう短めにする
    public static func makeGuide(host: String) -> Mirakurun? {
        host.isEmpty ? nil : Mirakurun(host: host, timeout: 3)
    }

    // MARK: - リモコン

    public func send(_ key: RegzaKey) {
        tapCount += 1
        guard !isSampleMode else { return }
        Task {
            do {
                try await remote.send(key)
                // テレビ側の状態が変わるのを少し待ってから反映する
                try? await Task.sleep(for: .milliseconds(400))
                _ = await fetch()
                lastError = nil
                nowPlaying = await remote.nowPlaying
            } catch {
                lastError = RegzaError(error)
            }
        }
    }

    public func seek(to seconds: Int) {
        Task {
            do {
                try await remote.seek(to: seconds)
                _ = await fetch()
                nowPlaying = await remote.nowPlaying
            } catch {
                lastError = RegzaError(error)
            }
        }
    }

    // MARK: - チャンネル

    /// 番組表とチャンネル一覧で選んでいる放送の種類 (地デジ・BS・CS)。タブを行き来しても同じものを出す。未選択なら nil
    public var selectedBand: RegzaChannel.Band?

    /// 放送の種類を選んでいなければ、いま見ている放送の種類、それもなければ一覧の最初のものにする
    public func band(among bands: [RegzaChannel.Band]) -> RegzaChannel.Band? {
        .preferred(among: bands, selected: selectedBand, nowPlaying: nowPlayingChannel?.band)
    }

    /// テレビに登録されているチャンネル。取得前は空
    public private(set) var channels: [RegzaChannel] = []

    /// いま映っている放送のチャンネル
    public var nowPlayingChannel: RegzaChannel? {
        guard let code = nowPlaying?.channelCode, !code.isEmpty else { return nil }
        return channels.first { $0.code == code }
    }

    /// チャンネル一覧を取得する。チャンネルの登録はあまり変わらないので、取得済みなら使い回す
    public func loadChannels(force: Bool = false) async throws(RegzaError) {
        guard !isSampleMode, force || channels.isEmpty else { return }
        do {
            channels = try await remote.client.channels()
        } catch {
            throw RegzaError(error)
        }
    }

    public func tune(to channel: RegzaChannel) async throws(RegzaError) {
        tapCount += 1
        do {
            try await remote.tune(to: channel)
        } catch {
            throw RegzaError(error)
        }
        // 切り替えの最中は play/status を問い合わせない (RegzaRemote) ので、取り直さずに、
        // 選んだチャンネルに切り替わったものとして出す。番組名などは定期の取得で落ち着いてから反映する
        lastError = nil
        nowPlaying = await remote.nowPlaying
        await observer?.remoteViewModel(self, didUpdate: nowPlaying, isConnected: true)
        await observer?.remoteViewModelDidTune(self)
    }

    // MARK: - 状態の定期取得

    public func startPolling(interval: Duration = .seconds(2)) {
        guard pollingTask == nil, connection.isConfigured, !isSampleMode else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
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
        isSearchingTV = true
        defer { isSearchingTV = false }
        let original = connection
        guard let host = await RegzaDiscovery.locate(original),
              // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
              !Task.isCancelled, connection == original
        else { return }
        var moved = original
        moved.host = host
        store.save(moved)
        connection = moved
        await remote.update(connection: store.load())
        await refresh()
    }

    // MARK: - 設定

    public func save(_ connection: RegzaConnection) async {
        store.save(connection)
        self.connection = connection
        nowPlaying = nil
        channels = []
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

    /// テレビとのやり取りの外で起きたエラーを出す (iOS の Live Activity を始められなかったときなど)
    public func report(_ error: RegzaError) {
        lastError = error
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    public func pairingUserID() -> String {
        store.pairingUserID()
    }

    /// 保存前の接続情報で視聴状況を取得してみる (普段と同じく v2 API を優先し、無ければ旧 API)
    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        do {
            return .success(try await RegzaRemote(connection: connection).refresh())
        } catch {
            return .failure(RegzaError(error))
        }
    }
}

extension RegzaError {
    /// RegzaError 以外のエラーは通信のエラーとして扱う
    init(_ error: any Error) {
        self = error as? RegzaError ?? .network(error.localizedDescription)
    }
}
