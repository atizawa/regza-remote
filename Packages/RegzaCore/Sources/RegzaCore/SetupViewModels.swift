import Foundation
import Observation

/// テレビの設定の画面の ViewModel (iOS と Android で共有)。
/// 同じネットワークのテレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
@MainActor
@Observable
public final class TVSetupViewModel {
    public let remote: RemoteViewModel
    public let setup: SetupUseCase
    /// このアプリ用のユーザー ID。手入力のユーザー名は他のツールと共有している
    /// かもしれないので使い回さない (同じ ID で登録し直すと、前のパスワードが無効になる)
    public let pairingUserID: String

    public init(remote: RemoteViewModel, setup: SetupUseCase) {
        self.remote = remote
        self.setup = setup
        draft = remote.connection
        pairingUserID = remote.pairingUserID()
    }

    public struct State: Equatable, Sendable {
        /// 入力中の接続情報 (保存するまで RemoteViewModel には入れない)
        public var draft: RegzaConnection
        /// 見つかったテレビ
        public var devices: [Device]
        public var isScanning: Bool
        public var scanMessage: String?
        /// テレビに PIN が表示されていて、入力を待っている
        public var isWaitingForPIN: Bool
        public var pin: String
        public var isPairing: Bool
        public var pairingMessage: String?
        /// PIN で登録して保存できた (画面を閉じる)
        public var hasRegistered: Bool
        /// このアプリの ID で登録済みか
        public var isRegistered: Bool
        /// ユーザー名とパスワードの入力欄を開いているか (PIN 登録に対応していない機種なら開く)
        public var isShowingManualEntry: Bool
        public var isTesting: Bool
        public var testResult: String?
        /// 一覧に出すテレビの状態
        public var status: Status
        /// 保存できるか (アドレスがあり、PIN の入力を待っていない)
        public var canSave: Bool
    }

    public struct Device: Equatable, Sendable, Identifiable {
        public var device: RegzaDevice
        public var isSelected: Bool
        public var id: String { device.id }
    }

    /// 操作できるときはアドレスだけ、注意が要るときだけ目立たせる
    public struct Status: Equatable, Sendable {
        public var text: String
        public var needsAttention: Bool
    }

    public enum Action: Sendable {
        /// 画面を開いた。未設定なら探し始める
        case appear
        case setHost(String)
        case setUser(String)
        case setPassword(String)
        case setPIN(String)
        case setShowingManualEntry(Bool)
        case scan
        /// 未登録なら、選んだテレビにそのまま PIN を表示させる。
        /// 登録済みなら IP アドレスだけ変える (DHCP でアドレスが変わった場合など)
        case select(RegzaDevice)
        case startPairing
        /// PIN で登録を確定して保存する
        case confirmPairing
        case cancelPairing
        case test
        /// 画面を閉じた。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
        case close
    }

    private var draft: RegzaConnection
    private var devices: [RegzaDevice] = []
    private var isScanning = false
    private var scanMessage: String?
    /// PIN 登録中 (テレビに PIN が表示されている間) のセッション
    @ObservationIgnored private var pairing: (any PairingSession)?
    private var isWaitingForPIN = false
    private var pin = ""
    private var isPairing = false
    private var pairingMessage: String?
    private var hasRegistered = false
    private var isShowingManualEntry = false
    private var isTesting = false
    private var testResult: String?
    @ObservationIgnored private let work = Work()

    public var state: State {
        State(
            draft: draft,
            devices: devices.map { Device(device: $0, isSelected: draft.host == $0.host) },
            isScanning: isScanning,
            scanMessage: scanMessage,
            isWaitingForPIN: isWaitingForPIN,
            pin: pin,
            isPairing: isPairing,
            pairingMessage: pairingMessage,
            hasRegistered: hasRegistered,
            isRegistered: isRegistered,
            isShowingManualEntry: isShowingManualEntry,
            isTesting: isTesting,
            testResult: testResult,
            status: status,
            canSave: draft.isConfigured && !isWaitingForPIN
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            if !remote.connection.isConfigured && devices.isEmpty && !isScanning { work.run { await self.scan() } }
        case .setHost(let host): draft.host = host
        case .setUser(let user): draft.user = user
        case .setPassword(let password): draft.password = password
        case .setPIN(let newPIN): pin = newPIN
        case .setShowingManualEntry(let isShowing): isShowingManualEntry = isShowing
        case .scan:
            guard !isScanning else { return }
            work.run { await self.scan() }
        case .select(let device):
            draft.host = device.host
            if device.supportsPIN, !isRegistered { work.run { await self.startPairing() } }
        case .startPairing: work.run { await self.startPairing() }
        case .confirmPairing: work.run { await self.confirmPairing() }
        case .cancelPairing: work.run { await self.cancelPairing() }
        case .test: work.run { await self.test() }
        case .close: close()
        }
    }

    private var isRegistered: Bool {
        !pairingUserID.isEmpty && draft.user == pairingUserID && !draft.password.isEmpty
    }

    private var status: Status {
        let host = draft.host.trimmingCharacters(in: .whitespaces)
        if host.isEmpty { return Status(text: "未設定", needsAttention: true) }
        // PIN の登録でも手入力でも、パスワードがなければ操作できない
        if draft.password.isEmpty { return Status(text: "PIN の登録が必要", needsAttention: true) }
        return Status(text: host, needsAttention: false)
    }

    // MARK: - テレビを探す

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        scanMessage = nil
        devices = []
        for await device in setup.findTVs() {
            devices.append(device)
            // 1 台目は選んでおく。登録は利用者がボタンを押してから
            if devices.count == 1, draft.host.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.host = device.host
            }
        }
        if devices.isEmpty {
            #if os(iOS)
            scanMessage = "見つかりませんでした。テレビの電源が入っているか、iPhone の「設定」→「プライバシーとセキュリティ」→「ローカルネットワーク」でこのアプリが許可されているか確認してください。"
            #else
            scanMessage = "見つかりませんでした。テレビの電源が入っているか、テレビと同じ Wi-Fi につながっているか確認してください。"
            #endif
        }
    }

    // MARK: - PIN で登録

    private func startPairing() async {
        isPairing = true
        defer { isPairing = false }
        pairingMessage = nil
        // 登録し直すときはアプリの ID を使い回し、テレビの登録機器が増えないようにする
        let session = setup.pairing(host: draft.host, user: pairingUserID)
        do {
            try await session.start()
            pairing = session
            pin = ""
            isWaitingForPIN = true
        } catch RegzaError.unsupported, RegzaError.httpStatus(404) {
            pairingMessage = "この機種は PIN 登録に対応していません。下の「ユーザー名とパスワードを入力」から設定してください。"
            isShowingManualEntry = true
        } catch {
            pairingMessage = error.localizedDescription
        }
    }

    private func confirmPairing() async {
        guard let pairing else { return }
        isPairing = true
        defer { isPairing = false }
        do {
            draft = try await pairing.confirm(pin: pin)
            self.pairing = nil
            isWaitingForPIN = false
            await remote.save(draft)
            hasRegistered = true
        } catch {
            // PIN の打ち間違いはそのまま入力し直せるようにする
            pairingMessage = error.localizedDescription
        }
    }

    private func cancelPairing() async {
        await pairing?.cancel()
        pairing = nil
        isWaitingForPIN = false
        pin = ""
        pairingMessage = nil
    }

    private func close() {
        guard let pairing else { return }
        self.pairing = nil
        isWaitingForPIN = false
        Task { await pairing.cancel() }
    }

    // MARK: - 接続テスト

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        switch await remote.testConnection(draft) {
        case .success(let nowPlaying):
            let detail = nowPlaying.title.isEmpty ? nowPlaying.channelName : nowPlaying.title
            testResult = detail.isEmpty ? "接続できました" : "接続できました: \(detail)"
        case .failure(let error):
            testResult = error.localizedDescription
        }
    }

    // MARK: - 保存

    /// 入力した接続情報を保存する (設定の画面の「保存」から、AppViewModel が呼ぶ)
    func save() async {
        await remote.save(draft)
    }
}

extension TVSetupViewModel: Introspectable {
    public var introspectionName: String { "tv" }
    public var isBusy: Bool { work.isBusy }

    /// パスワードは見せない (入っているかどうかだけ)
    public var introspectionValue: Any {
        var state = state
        if !state.draft.password.isEmpty { state.draft.password = "(入力済み)" }
        return state
    }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("setHost", "テレビの IP アドレスを入れる", parameters: ["host": "IP アドレス"]),
            ActionDescription("setUser", "ユーザー名を入れる (PIN 登録に対応していない機種)", parameters: ["user": "ユーザー名"]),
            ActionDescription("setPassword", "パスワードを入れる (PIN 登録に対応していない機種)", parameters: ["password": "パスワード"]),
            ActionDescription("scan", "同じネットワークのテレビを探す"),
            ActionDescription("select", "見つかったテレビを選ぶ (未登録なら PIN を表示させる)", parameters: ["host": "devices の host"]),
            ActionDescription("startPairing", "テレビに PIN を表示させる"),
            ActionDescription("setPIN", "テレビに表示された PIN を入れる", parameters: ["pin": "PIN"]),
            ActionDescription("confirmPairing", "PIN で登録して保存する"),
            ActionDescription("cancelPairing", "PIN の登録をやめる"),
            ActionDescription("test", "入力した接続情報でつながるか試す"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "setHost": send(.setHost(try arguments.string("host")))
        case "setUser": send(.setUser(try arguments.string("user")))
        case "setPassword": send(.setPassword(try arguments.string("password")))
        case "scan": send(.scan)
        case "select":
            let host = try arguments.string("host")
            guard let device = devices.first(where: { $0.host == host }) else {
                throw IntrospectionError.unavailable("テレビ \(host) は見つかっていません")
            }
            send(.select(device))
        case "startPairing": send(.startPairing)
        case "setPIN": send(.setPIN(try arguments.string("pin")))
        case "confirmPairing": send(.confirmPairing)
        case "cancelPairing": send(.cancelPairing)
        case "test": send(.test)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}

/// 録画サーバー (番組表の Mirakurun・ライブ視聴の EPGStation) の設定の画面の ViewModel (iOS と Android で共有)
@MainActor
@Observable
public final class ServerSetupViewModel {
    public let setup: SetupUseCase

    public init(setup: SetupUseCase) {
        self.setup = setup
        guideHost = setup.linkedGuideHost
        streamHost = setup.linkedStreamHost
    }

    public enum Server: String, CaseIterable, Sendable {
        case guide, stream
    }

    public struct State: Equatable, Sendable {
        public var guide: ServerState
        public var stream: ServerState
        /// Mirakurun のアドレスが入っているか (保存前の入力も含む)。EPGStation は Mirakurun から放送を受け取るので、
        /// Mirakurun を入れてから設定できるようにする
        public var hasGuideDraft: Bool
        /// 入力したポートが正しいか
        public var isValid: Bool

        public subscript(server: Server) -> ServerState { server == .guide ? guide : stream }
    }

    /// 1 つの録画サーバーの設定
    public struct ServerState: Equatable, Sendable {
        /// 入力中のアドレス (`192.168.0.2` か `192.168.0.2:40772`)
        public var host: String
        public var defaultPort: Int
        /// 探して見つかったアドレス
        public var hosts: [String]
        public var isScanning: Bool
        public var message: String?
        /// 一覧に出す状態 (アドレスか「未設定」)
        public var status: String
        /// 保存済みで、連携を解除できるか
        public var isLinked: Bool
        /// 解除するか確かめるときの見出しと説明
        public var unlinkTitle: String
        public var unlinkMessage: String
    }

    public enum Action: Sendable {
        case setHost(Server, String)
        case scan(Server)
        /// Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
        case suggestStreamHost
        /// 連携をやめる。すぐにアドレスを消して反映する。EPGStation だけでは使えないので、番組表を外したら一緒に外す
        case unlink(Server)
    }

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

    public func send(_ action: Action) {
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

    /// 入力したアドレスを保存する (設定の画面の「保存」から、AppViewModel が呼ぶ)
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
        func server() throws -> Server {
            guard let server = Server(rawValue: try arguments.string("server")) else { throw IntrospectionError.invalidArgument("server") }
            return server
        }
        switch action {
        case "setHost": send(.setHost(try server(), try arguments.string("host")))
        case "scan": send(.scan(try server()))
        case "suggestStreamHost": send(.suggestStreamHost)
        case "unlink": send(.unlink(try server()))
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}

/// 録画サーバーのアドレス。保存するときは `192.168.0.2` か `192.168.0.2:40780` の 1 つの文字列にする
public struct ServerAddress: Equatable, Sendable {
    public var address: String
    /// 空なら標準のポート
    public var port: String

    public init(address: String, port: String) {
        self.address = address
        self.port = port
    }

    /// `host` か `host:port` を分ける
    public init(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        if let colon = text.lastIndex(of: ":"), text[text.index(after: colon)...].allSatisfy(\.isNumber) {
            address = String(text[..<colon])
            port = String(text[text.index(after: colon)...])
        } else {
            address = text
            port = ""
        }
    }

    public var combined: String {
        let address = address.trimmingCharacters(in: .whitespaces)
        let port = port.trimmingCharacters(in: .whitespaces)
        // アドレスより先にポートを入れても消えないよう、アドレスが空でもポートは残す
        return port.isEmpty ? address : "\(address):\(port)"
    }

    /// 保存する値。アドレスが空なら連携しない (ポートだけ入っていても空にする)
    public var saved: String {
        address.trimmingCharacters(in: .whitespaces).isEmpty ? "" : combined
    }

    /// ポートが空か 1〜65535 の数字
    public var isValid: Bool {
        let port = port.trimmingCharacters(in: .whitespaces)
        guard !port.isEmpty else { return true }
        return Int(port).map { (1...65535).contains($0) } ?? false
    }
}
