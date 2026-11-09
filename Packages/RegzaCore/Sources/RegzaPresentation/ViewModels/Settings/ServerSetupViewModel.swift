public import Foundation
public import Observation
package import RegzaDomain

/// 設定の中の録画サーバー (番組表の Mirakurun・ライブ視聴の EPGStation) の設定 (SettingsViewModel の部品)
@MainActor
@Observable
public final class ServerSetupViewModel {
    package let setup: any SetupUseCaseProtocol

    package init(setup: any SetupUseCaseProtocol) {
        self.setup = setup
        guideHost = setup.linkedGuideHost
        streamHost = setup.linkedStreamHost
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
                host: guideHost, defaultPort: ServerPort.mirakurun, hosts: guideHosts, isScanning: isScanningGuide,
                message: guideMessage, status: Self.status(guideHost), isLinked: !setup.linkedGuideHost.isEmpty,
                unlinkTitle: "Mirakurun との連携を解除しますか？",
                unlinkMessage: "番組名・番組表・番組表からの録画予約が使えなくなります。ライブ視聴（EPGStation）の連携も解除されます。"
            ),
            stream: ServerState(
                host: streamHost, defaultPort: ServerPort.epgStation, hosts: streamHosts, isScanning: isScanningStream,
                message: streamMessage, status: Self.status(streamHost), isLinked: !setup.linkedStreamHost.isEmpty,
                unlinkTitle: "EPGStation との連携を解除しますか？",
                unlinkMessage: "アプリでのライブ視聴が使えなくなります。"
            ),
            hasGuideDraft: !ServerAddress(guideHost).saved.isEmpty,
            isValid: ServerAddress(guideHost).isValid && ServerAddress(streamHost).isValid
        )
    }

    /// CLI からの操作を送る先。設定の ViewModel を通す (SettingsViewModel が入れる)
    @ObservationIgnored var forward: ((ServerSetupAction) -> Void)?

    /// 操作は設定の ViewModel (SettingsViewModel) から送る
    func send(_ action: ServerSetupAction) {
        switch action {
        case .setHost(.guide, let host): guideHost = host
        case .setHost(.stream, let host): streamHost = host
        case .scan(.guide): work.run { await self.scanGuide() }
        case .scan(.stream): work.run { await self.scanStream() }
        case .suggestStreamHost: work.run { await self.suggestStreamHost() }
        case .unlink(let server): work.run { await self.unlink(server) }
        }
    }

    private static func status(_ host: String) -> String {
        let host = ServerAddress(host).saved
        return host.isEmpty ? "未設定" : host
    }

    private func scanGuide() async {
        isScanningGuide = true
        defer { isScanningGuide = false }
        guideMessage = nil
        guideHosts = await setup.findGuideServers()
        if let first = guideHosts.first, guideHost.trimmingCharacters(in: .whitespaces).isEmpty {
            guideHost = first
        }
        if guideHosts.isEmpty {
            guideMessage = "見つかりませんでした。Mirakurun が動いているか、ポート \(ServerPort.mirakurun) で待ち受けているか確認してください。"
        }
    }

    private func scanStream() async {
        isScanningStream = true
        defer { isScanningStream = false }
        streamMessage = nil
        streamHosts = await setup.findStreamServers()
        if let first = streamHosts.first, streamHost.trimmingCharacters(in: .whitespaces).isEmpty {
            streamHost = first
        }
        if streamHosts.isEmpty {
            streamMessage = "見つかりませんでした。EPGStation が動いているか、ポート \(ServerPort.epgStation) で待ち受けているか確認してください。"
        }
    }

    func suggestStreamHost() async {
        guard streamHost.trimmingCharacters(in: .whitespaces).isEmpty, streamHosts.isEmpty else { return }
        // Mirakurun のアドレスからポートを除いたもの
        guard let server = await setup.streamServer(sameAs: ServerAddress(guideHost).address) else { return }
        streamHosts = [server]
        streamHost = server
        streamMessage = "Mirakurun と同じサーバーで EPGStation が見つかりました。よければ「保存」を押してください。"
    }

    func unlink(_ server: Server) async {
        // EPGStation は Mirakurun から放送を受け取るので、番組表を外したらライブ視聴も外れる (SetupUseCase)
        if server == .guide {
            guideHost = ""
            guideHosts = []
            await setup.unlinkGuide()
        } else {
            setup.unlinkStream()
        }
        streamHost = ""
        streamHosts = []
    }

    /// 入力したアドレスを保存する (設定の画面の「保存」から、SettingsViewModel が呼ぶ)
    func save() async {
        await setup.saveServers(guideHost: ServerAddress(guideHost).saved, streamHost: ServerAddress(streamHost).saved)
    }
}

extension ServerSetupViewModel: Introspectable {
    public var introspectionName: String { "servers" }
    public var introspectionValue: Any { state }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        let server = Server.allCases.map(\.rawValue).joined(separator: " | ")
        return [
            ActionDescription("setHost", "アドレスを入れる", parameters: ["server": server, "host": "192.0.2.2 か 192.0.2.2:40772"]),
            ActionDescription("scan", "同じネットワークで探す", parameters: ["server": server]),
            ActionDescription("suggestStreamHost", "Mirakurun と同じサーバーの EPGStation を探す"),
            ActionDescription("unlink", "連携を解除する (番組表を外すとライブ視聴も外れる)", parameters: ["server": server]),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        func deliver(_ action: ServerSetupAction) { (forward ?? send)(action) }
        func server() throws -> Server {
            guard let server = Server(rawValue: try arguments.string("server")) else { throw IntrospectionError.invalidArgument("server") }
            return server
        }
        switch action {
        case "setHost": deliver(.setHost(try server(), try arguments.string("host")))
        case "scan": deliver(.scan(try server()))
        case "suggestStreamHost": deliver(.suggestStreamHost)
        case "unlink": deliver(.unlink(try server()))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
