import Foundation
import Observation
import RegzaDomain

/// テレビ (REGZA) とのやり取り (TVRepositoryProtocol の実装)。RegzaRemote (切り替えの最中は問い合わせないしくみ) を使う
@MainActor
@Observable
public final class RegzaTVRepository: TVRepositoryProtocol {
    @ObservationIgnored private let secureStorageManager: SecureStorageManager
    @ObservationIgnored private let preferencesManager: PreferencesManager
    /// テレビのリモコン
    @ObservationIgnored public let regzaRemote: RegzaRemote
    @ObservationIgnored private let regzaAPIClient: RegzaAPIClient
    @ObservationIgnored private let connectionState: RegzaConnectionState

    public var connection: ConnectionData { connectionState.connection }
    public private(set) var channels: [ChannelData] = []
    /// 読み込んだ設定と、そのときの接続。接続が変わったら使わない
    private var loadedTimeshift: (settings: TimeshiftSettingsData, revision: Int)?
    public var isSample: Bool { false }

    public init(
        secureStorageManager: SecureStorageManager, preferencesManager: PreferencesManager, regzaAPIClient: RegzaAPIClient,
        connectionState: RegzaConnectionState,
        regzaRemote: RegzaRemote? = nil
    ) {
        if let regzaRemote { precondition(regzaRemote.regzaAPIClient === regzaAPIClient, "remote と Repository は同じ APIClient を共有してください") }
        self.secureStorageManager = secureStorageManager
        self.preferencesManager = preferencesManager
        self.regzaAPIClient = regzaAPIClient
        self.connectionState = connectionState
        self.regzaRemote = regzaRemote ?? RegzaRemote(regzaAPIClient: regzaAPIClient)
    }

    public var timeshiftSettings: TimeshiftSettingsData? {
        loadedTimeshift.flatMap { $0.revision == connectionState.revision ? $0.settings : nil }
    }

    public func loadChannels(force: Bool) async throws(RegzaError) {
        guard force || channels.isEmpty else { return }
        let revision = connectionState.revision
        do {
            let channels = try await regzaAPIClient.request(RegzaChannelsRequest())
            guard revision == connectionState.revision else { return }
            self.channels = channels
        } catch {
            throw RegzaError(error)
        }
    }

    public func loadTimeshiftSettings() async {
        guard timeshiftSettings == nil else { return }
        let revision = connectionState.revision
        guard let settings = try? await regzaAPIClient.request(RegzaTimeshiftSettingsRequest()), revision == connectionState.revision else {
            return
        }
        loadedTimeshift = (settings, revision)
    }

    public func send(_ key: RegzaKey) async throws(RegzaError) {
        do {
            try await regzaRemote.send(key)
        } catch {
            throw RegzaError(error)
        }
    }

    public func tune(to channel: ChannelData) async throws(RegzaError) -> NowPlayingData? {
        do {
            try await regzaRemote.tune(to: channel)
        } catch {
            throw RegzaError(error)
        }
        return await regzaRemote.nowPlaying
    }

    public func seek(to seconds: Int) async throws(RegzaError) {
        do {
            try await regzaRemote.seek(to: seconds)
        } catch {
            throw RegzaError(error)
        }
    }

    public func refresh() async throws(RegzaError) -> NowPlayingData {
        do {
            return try await regzaRemote.refresh()
        } catch {
            throw RegzaError(error)
        }
    }

    public func lastNowPlaying() async -> NowPlayingData? {
        await regzaRemote.nowPlaying
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
        await regzaRemote.update(
            connection: Self.loadConnection(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager))
        return moved
    }

    public func save(_ connection: ConnectionData) async {
        persist(connection)
        connectionState.update(connection)
        channels = []
        await regzaRemote.update(
            connection: Self.loadConnection(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager))
    }

    public func testConnection(_ connection: ConnectionData) async -> Result<NowPlayingData, RegzaError> {
        do {
            let testAPIClient = await regzaAPIClient.replacingConnection(connection)
            return .success(try await RegzaRemote(regzaAPIClient: testAPIClient).refresh())
        } catch {
            return .failure(RegzaError(error))
        }
    }

    public func pairingUserID() -> String {
        secureStorageManager.value(forKey: .pairingUserID, orCreate: PairingUserID.make)
    }

    public nonisolated static func loadConnection(
        secureStorageManager: SecureStorageManager, preferencesManager: PreferencesManager
    ) -> ConnectionData {
        ConnectionData(
            host: preferencesManager.value(forKey: .host) ?? "",
            user: preferencesManager.value(forKey: .user) ?? "",
            password: secureStorageManager.value(forKey: .password) ?? ""
        )
    }

    private func persist(_ connection: ConnectionData) {
        preferencesManager.setValue(connection.host.trimmingCharacters(in: .whitespaces), forKey: .host)
        preferencesManager.setValue(connection.user, forKey: .user)
        secureStorageManager.setValue(connection.password, forKey: .password)
    }

    /// 組み立て側から、注入された通信設定を保った番組表クライアントへ差し替える。
    public func updateGuide(mirakurunAPIClient: MirakurunAPIClient?) async {
        await regzaRemote.update(mirakurunAPIClient: mirakurunAPIClient)
    }
}
