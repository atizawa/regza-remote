import RegzaDomain
import RegzaInfrastructure
import RegzaPresentation

/// APIClient・StorageManager から、本番用の Repository を組み立てる。
@MainActor
public enum AppFactory {
    /// 通信・保存の実装は OS の起動処理から渡す。グローバル設定は参照しない。
    public static func makeLiveAppViewModel(
        secureStorageManager: SecureStorageManager,
        preferencesManager: PreferencesManager,
        transport: any HTTPTransport
    ) -> AppViewModel {
        let connectionState = RegzaConnectionState(
            connection: RegzaTVRepository.loadConnection(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
        )
        let regzaAPIClient = RegzaAPIClient(connection: connectionState.connection, transport: transport)
        let guideHost = preferencesManager.value(forKey: .guideHost) ?? ""
        let guideAPIClient = MirakurunAPIClient(host: guideHost, transport: transport)
        let remoteGuideAPIClient = MirakurunAPIClient(host: guideHost, timeout: 3, transport: transport)
        let regzaRemote = RegzaRemote(
            regzaAPIClient: regzaAPIClient, mirakurunAPIClient: guideHost.isEmpty ? nil : remoteGuideAPIClient)
        let tvRepository = RegzaTVRepository(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager,
            regzaAPIClient: regzaAPIClient, connectionState: connectionState, regzaRemote: regzaRemote,
            locateTV: { await RegzaDiscovery.locate($0, transport: transport) })
        let guideRepository = MirakurunGuideRepository(preferencesManager: preferencesManager, mirakurunAPIClient: guideAPIClient)
        let streamRepository = EPGStationStreamRepository(
            preferencesManager: preferencesManager,
            epgStationAPIClient: EPGStationAPIClient(host: preferencesManager.value(forKey: .streamHost) ?? "", transport: transport))
        let recordingRepository = RegzaRecordingRepository(regzaAPIClient: regzaAPIClient, connectionState: connectionState)
        return makeAppViewModel(
            tvRepository: tvRepository, guideRepository: guideRepository,
            recordingRepository: recordingRepository, streamRepository: streamRepository,
            deviceRepository: NetworkDeviceRepository(transport: transport),
            appPreferencesRepository: AppPreferencesRepository(preferencesManager: preferencesManager),
            onGuideHostChange: { host in
                await tvRepository.updateGuide(mirakurunAPIClient: host.isEmpty ? nil : remoteGuideAPIClient.replacingHost(host))
            }
        )
    }
}
