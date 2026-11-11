import Foundation
import Observation
import RegzaDomain

/// テレビ (REGZA) とのやり取り (TVRepositoryProtocol の実装)。RegzaRemote (切り替えの最中は問い合わせないしくみ) を使う
@MainActor
@Observable
public final class RegzaTVRepository: TVRepositoryProtocol {
    @ObservationIgnored private let secureStorage: SecureStorageManager
    @ObservationIgnored private let preferences: PreferencesManager
    /// テレビのリモコン
    @ObservationIgnored public let remote: RegzaRemote
    @ObservationIgnored private let client: RegzaAPIClient
    @ObservationIgnored private let connectionState: RegzaConnectionState

    public var connection: ConnectionData { connectionState.connection }
    public private(set) var channels: [ChannelData] = []
    /// 読み込んだ設定と、そのときの接続。接続が変わったら使わない
    private var loadedTimeshift: (settings: TimeshiftSettingsData, revision: Int)?
    public var isSample: Bool { false }

    public init(
        secureStorage: SecureStorageManager, preferences: PreferencesManager, client: RegzaAPIClient, connectionState: RegzaConnectionState,
        remote: RegzaRemote? = nil
    ) {
        if let remote { precondition(remote.client === client, "remote と Repository は同じ APIClient を共有してください") }
        self.secureStorage = secureStorage
        self.preferences = preferences
        self.client = client
        self.connectionState = connectionState
        self.remote = remote ?? RegzaRemote(client: client)
    }

    public var timeshiftSettings: TimeshiftSettingsData? {
        loadedTimeshift.flatMap { $0.revision == connectionState.revision ? $0.settings : nil }
    }

    public func loadChannels(force: Bool) async throws(RegzaError) {
        guard force || channels.isEmpty else { return }
        let revision = connectionState.revision
        do {
            let channels = try await client.request(RegzaChannelsRequest())
            guard revision == connectionState.revision else { return }
            self.channels = channels
        } catch {
            throw RegzaError(error)
        }
    }

    public func loadTimeshiftSettings() async {
        guard timeshiftSettings == nil else { return }
        let revision = connectionState.revision
        guard let settings = try? await client.request(RegzaTimeshiftSettingsRequest()), revision == connectionState.revision else {
            return
        }
        loadedTimeshift = (settings, revision)
    }

    public func send(_ key: RegzaKey) async throws(RegzaError) {
        do {
            try await remote.send(key)
        } catch {
            throw RegzaError(error)
        }
    }

    public func tune(to channel: ChannelData) async throws(RegzaError) -> NowPlayingData? {
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

    public func refresh() async throws(RegzaError) -> NowPlayingData {
        do {
            return try await remote.refresh()
        } catch {
            throw RegzaError(error)
        }
    }

    public func lastNowPlaying() async -> NowPlayingData? {
        await remote.nowPlaying
    }

    public func locateMovedTV() async -> ConnectionData? {
        let original = connection
        guard let host = await RegzaDiscovery.locate(original),
            // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
            !Task.isCancelled, connection == original
        else { return nil }
        var moved = original
        moved.host = host
        persist(moved)
        connectionState.update(moved)
        channels = []
        await remote.update(connection: Self.loadConnection(secureStorage: secureStorage, preferences: preferences))
        return moved
    }

    public func save(_ connection: ConnectionData) async {
        persist(connection)
        connectionState.update(connection)
        channels = []
        await remote.update(connection: Self.loadConnection(secureStorage: secureStorage, preferences: preferences))
    }

    public func testConnection(_ connection: ConnectionData) async -> Result<NowPlayingData, RegzaError> {
        do {
            let testClient = await client.replacingConnection(connection)
            return .success(try await RegzaRemote(client: testClient).refresh())
        } catch {
            return .failure(RegzaError(error))
        }
    }

    public func pairingUserID() -> String {
        secureStorage.value(forKey: .pairingUserID, orCreate: PairingUserID.make)
    }

    public nonisolated static func loadConnection(
        secureStorage: SecureStorageManager, preferences: PreferencesManager
    ) -> ConnectionData {
        ConnectionData(
            host: preferences.value(forKey: .host) ?? "",
            user: preferences.value(forKey: .user) ?? "",
            password: secureStorage.value(forKey: .password) ?? ""
        )
    }

    private func persist(_ connection: ConnectionData) {
        preferences.setValue(connection.host.trimmingCharacters(in: .whitespaces), forKey: .host)
        preferences.setValue(connection.user, forKey: .user)
        secureStorage.setValue(connection.password, forKey: .password)
    }

    /// 組み立て側から、注入された通信設定を保った番組表クライアントへ差し替える。
    public func updateGuide(client: MirakurunAPIClient?) async {
        await remote.update(guide: client)
    }
}
