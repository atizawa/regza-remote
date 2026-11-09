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

// 設定の画面 (SettingsViewModel) が、CLI の操作「server.〜」として見せる (部品なので、ここだけでは道を持たない)
extension ServerSetupViewModel {
    var isBusy: Bool { work.isBusy }

    static var introspectionActions: [ActionDescription] {
        let server = ServerSetupServer.allCases.map(\.rawValue).joined(separator: " | ")
        return [
            ActionDescription("setHost", "アドレスを入れる", parameters: ["server": server, "host": "192.0.2.2 か 192.0.2.2:40772"]),
            ActionDescription("scan", "同じネットワークで探す", parameters: ["server": server]),
            ActionDescription("suggestStreamHost", "Mirakurun と同じサーバーの EPGStation を探す"),
            ActionDescription("unlink", "連携を解除する (番組表を外すとライブ視聴も外れる)", parameters: ["server": server]),
        ]
    }

    func introspectionAction(_ name: String, _ arguments: [String: JSONValue]) throws -> ServerSetupAction {
        func server() throws -> ServerSetupServer {
            guard let server = ServerSetupServer(rawValue: try arguments.string("server")) else { throw IntrospectionError.invalidArgument("server") }
            return server
        }
        switch name {
        case "setHost": return .setHost(try server(), try arguments.string("host"))
        case "scan": return .scan(try server())
        case "suggestStreamHost": return .suggestStreamHost
        case "unlink": return .unlink(try server())
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
