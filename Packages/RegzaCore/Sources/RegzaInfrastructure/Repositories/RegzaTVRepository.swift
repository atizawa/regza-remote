import Foundation
import Observation
import RegzaDomain

/// テレビ (REGZA) とのやり取り (TVRepositoryProtocol の実装)。RegzaRemote (切り替えの最中は問い合わせないしくみ) を使う
@MainActor
@Observable
public final class RegzaTVRepository: TVRepositoryProtocol {
    @ObservationIgnored public let store: any RegzaConnectionStore
    /// テレビのリモコン
    @ObservationIgnored public let remote: RegzaRemote

    public private(set) var connection: RegzaConnection
    public private(set) var channels: [RegzaChannel] = []
    /// 読み込んだ設定と、そのときの接続。接続が変わったら使わない
    private var loadedTimeshift: (settings: RegzaTimeshiftSettings, connection: RegzaConnection)?
    public var isSample: Bool { false }

    /// - Parameter remote: 渡さなければ、保存されている接続と番組表のアドレスで作る
    public init(store: any RegzaConnectionStore, remote: RegzaRemote? = nil) {
        self.store = store
        let connection = store.load()
        self.connection = connection
        self.remote = remote ?? RegzaRemote(connection: connection, guide: Self.makeGuide(host: store.guideHost))
    }

    /// 番組名を補う番組表 (Mirakurun)。視聴状況を 2 秒ごとに取るので、応答しないときに待たされないよう短めにする
    public static func makeGuide(host: String) -> Mirakurun? {
        host.isEmpty ? nil : Mirakurun(host: host, timeout: 3)
    }

    public var timeshiftSettings: RegzaTimeshiftSettings? {
        loadedTimeshift.flatMap { $0.connection == connection ? $0.settings : nil }
    }

    public func loadChannels(force: Bool) async throws(RegzaError) {
        guard force || channels.isEmpty else { return }
        do {
            channels = try await remote.client.channels()
        } catch {
            throw RegzaError(error)
        }
    }

    public func loadTimeshiftSettings() async {
        guard timeshiftSettings == nil else { return }
        let connection = connection
        guard let settings = try? await remote.client.timeshiftSettings() else { return }
        loadedTimeshift = (settings, connection)
    }

    public func send(_ key: RegzaKey) async throws(RegzaError) {
        do {
            try await remote.send(key)
        } catch {
            throw RegzaError(error)
        }
    }

    public func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        do {
            try await remote.tune(to: channel)
        } catch {
            throw RegzaError(error)
        }
        return await remote.nowPlaying
    }

    public func seek(to seconds: Int) async throws(RegzaError) {
        do {
            try await remote.seek(to: seconds)
        } catch {
            throw RegzaError(error)
        }
    }

    public func refresh() async throws(RegzaError) -> RegzaNowPlaying {
        do {
            return try await remote.refresh()
        } catch {
            throw RegzaError(error)
        }
    }

    public func lastNowPlaying() async -> RegzaNowPlaying? {
        await remote.nowPlaying
    }

    public func locateMovedTV() async -> RegzaConnection? {
        let original = connection
        guard let host = await RegzaDiscovery.locate(original),
              // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
              !Task.isCancelled, connection == original
        else { return nil }
        var moved = original
        moved.host = host
        store.save(moved)
        connection = moved
        await remote.update(connection: store.load())
        return moved
    }

    public func save(_ connection: RegzaConnection) async {
        store.save(connection)
        self.connection = connection
        channels = []
        await remote.update(connection: store.load())
    }

    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        do {
            return .success(try await RegzaRemote(connection: connection).refresh())
        } catch {
            return .failure(RegzaError(error))
        }
    }

    public func pairingUserID() -> String {
        store.pairingUserID()
    }

    /// 番組名を補う番組表のアドレスが変わった (番組表の Repository から呼ぶ)
    public func updateGuide(host: String) async {
        await remote.update(guide: Self.makeGuide(host: host))
    }
}
