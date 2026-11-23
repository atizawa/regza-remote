import Foundation
public import Observation
import PresentationCore
package import RegzaDomain
import RegzaStrings

/// 設定の中の録画サーバー (番組表の Mirakurun・ライブ視聴の EPGStation) の設定 (SettingsViewModel の部品)
@MainActor
@Observable
public final class ServerSetupViewModel {
    private let setupUseCase: any SetupUseCaseProtocol

    package init(setupUseCase: any SetupUseCaseProtocol) {
        self.setupUseCase = setupUseCase
        guideHost = setupUseCase.linkedGuideHost
        streamHost = setupUseCase.linkedStreamHost
    }

    /// 録画サーバーの種類
    public typealias Server = ServerSetupServer

    /// 画面に出すもの
    public typealias State = ServerSetupState

    /// 1 つの録画サーバーの設定
    public typealias ServerState = ServerSetupServerState

    private var guideHost: String
    private var streamHost: String
    private var guideHosts: [String] = []
    private var isScanningGuide = false
    private var guideMessage: String?
    private var streamHosts: [String] = []
    private var isScanningStream = false
    private var streamMessage: String?
    @ObservationIgnored private let work = Work()

    public var state: State {
        State(
            guide: ServerState(
                host: guideHost, address: ServerAddress(guideHost).address, port: ServerAddress(guideHost).port,
                isPortValid: ServerAddress(guideHost).isValid, defaultPort: ServerPort.mirakurun, hosts: guideHosts,
                isScanning: isScanningGuide,
                message: guideMessage, status: Self.status(guideHost), isLinked: !setupUseCase.linkedGuideHost.isEmpty,
                unlinkTitle: CoreStrings.serverGuideUnlinkTitle,
                unlinkMessage: CoreStrings.serverGuideUnlinkMessage
            ),
            stream: ServerState(
                host: streamHost, address: ServerAddress(streamHost).address, port: ServerAddress(streamHost).port,
                isPortValid: ServerAddress(streamHost).isValid, defaultPort: ServerPort.epgStation, hosts: streamHosts,
                isScanning: isScanningStream,
                message: streamMessage, status: Self.status(streamHost), isLinked: !setupUseCase.linkedStreamHost.isEmpty,
                unlinkTitle: CoreStrings.serverStreamUnlinkTitle,
                unlinkMessage: CoreStrings.serverStreamUnlinkMessage
            ),
            hasGuideDraft: !ServerAddress(guideHost).saved.isEmpty,
            isValid: ServerAddress(guideHost).isValid && ServerAddress(streamHost).isValid
        )
    }

    /// 操作は設定の ViewModel (SettingsViewModel) から送る
    func send(_ action: ServerSetupAction) {
        switch action {
        case .setHost(.guide, let host): guideHost = host
        case .setHost(.stream, let host): streamHost = host
        case .setAddress(.guide, let address): guideHost = ServerAddress(address: address, port: ServerAddress(guideHost).port).combined
        case .setAddress(.stream, let address): streamHost = ServerAddress(address: address, port: ServerAddress(streamHost).port).combined
        case .setPort(.guide, let port): guideHost = ServerAddress(address: ServerAddress(guideHost).address, port: port).combined
        case .setPort(.stream, let port): streamHost = ServerAddress(address: ServerAddress(streamHost).address, port: port).combined
        case .scan(.guide): work.run { await self.scanGuide() }
        case .scan(.stream): work.run { await self.scanStream() }
        case .suggestStreamHost: work.run { await self.suggestStreamHost() }
        case .unlink(let server): work.run { await self.unlink(server) }
        }
    }

    private static func status(_ host: String) -> String {
        let host = ServerAddress(host).saved
        return host.isEmpty ? CoreStrings.setupNotConfigured : host
    }

    private func scanGuide() async {
        isScanningGuide = true
        defer { isScanningGuide = false }
        guideMessage = nil
        guideHosts = await setupUseCase.findGuideServers()
        if let first = guideHosts.first, guideHost.trimmingCharacters(in: .whitespaces).isEmpty {
            guideHost = first
        }
        if guideHosts.isEmpty {
            guideMessage = CoreStrings.serverGuideNotFound(ServerPort.mirakurun)
        }
    }

    private func scanStream() async {
        isScanningStream = true
        defer { isScanningStream = false }
        streamMessage = nil
        streamHosts = await setupUseCase.findStreamServers()
        if let first = streamHosts.first, streamHost.trimmingCharacters(in: .whitespaces).isEmpty {
            streamHost = first
        }
        if streamHosts.isEmpty {
            streamMessage = CoreStrings.serverStreamNotFound(ServerPort.epgStation)
        }
    }

    func suggestStreamHost() async {
        guard streamHost.trimmingCharacters(in: .whitespaces).isEmpty, streamHosts.isEmpty else { return }
        // Mirakurun のアドレスからポートを除いたもの
        guard let server = await setupUseCase.streamServer(sameAs: ServerAddress(guideHost).address) else { return }
        streamHosts = [server]
        streamHost = server
        streamMessage = CoreStrings.serverStreamFound
    }

    func unlink(_ server: Server) async {
        // EPGStation は Mirakurun から放送を受け取るので、番組表を外したらライブ視聴も外れる (SetupUseCase)
        if server == .guide {
            guideHost = ""
            guideHosts = []
            await setupUseCase.unlinkGuide()
        } else {
            setupUseCase.unlinkStream()
        }
        streamHost = ""
        streamHosts = []
    }

    /// 入力したアドレスを保存する (設定の画面の「保存」から、SettingsViewModel が呼ぶ)
    func save() async {
        await setupUseCase.saveServers(guideHost: ServerAddress(guideHost).saved, streamHost: ServerAddress(streamHost).saved)
    }
}

// 設定の画面 (SettingsViewModel) が、CLI の操作「server.〜」として見せる (部品なので、ここだけでは道を持たない)
extension ServerSetupViewModel {
    var isBusy: Bool { work.isBusy }

    /// 設定の操作の表に入れる、この部品の操作 (名前の前に server. を付けて見せる)
    var introspectionTable: [IntrospectionAction<ServerSetupAction>] {
        let server = ActionParameter<Server>.choice("server")
        return [
            IntrospectionAction("setHost", "アドレスを入れる", server, .string("host", "192.0.2.2 か 192.0.2.2:40772")) { .setHost($0, $1) },
            IntrospectionAction("setAddress", "アドレスの欄を変える (ポートはそのまま)", server, .string("address", "192.0.2.2")) {
                .setAddress($0, $1)
            },
            IntrospectionAction("setPort", "ポートの欄を変える (空なら標準のポート)", server, .string("port", "40772")) { .setPort($0, $1) },
            IntrospectionAction("scan", "同じネットワークで探す", server) { .scan($0) },
            IntrospectionAction("suggestStreamHost", "Mirakurun と同じサーバーの EPGStation を探す", .suggestStreamHost),
            IntrospectionAction("unlink", "連携を解除する (番組表を外すとライブ視聴も外れる)", server) { .unlink($0) },
        ]
    }
}
