public import Foundation
public import Observation
package import RegzaDomain

/// 設定の中のテレビの登録 (SettingsViewModel の部品)。
/// 同じネットワークのテレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
@MainActor
@Observable
public final class TVSetupViewModel {
    public let remote: RemoteViewModel
    package let setup: any SetupUseCaseProtocol
    /// このアプリ用のユーザー ID。手入力のユーザー名は他のツールと共有している
    /// かもしれないので使い回さない (同じ ID で登録し直すと、前のパスワードが無効になる)
    public let pairingUserID: String

    package init(remote: RemoteViewModel, setup: any SetupUseCaseProtocol) {
        self.remote = remote
        self.setup = setup
        draft = remote.connection
        pairingUserID = remote.pairingUserID()
    }

    /// 画面に出すもの
    public typealias State = TVSetupState

    /// 一覧に出すテレビの状態
    public typealias Status = TVSetupStatus

    private var draft: RegzaConnection
    private var devices: [DeviceItem] = []
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
            host: draft.host,
            user: draft.user,
            password: draft.password,
            hasAddress: draft.isConfigured,
            devices: devices.map { device in
                var device = device
                device.isSelected = draft.host == device.host
                return device
            },
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

    /// 操作は設定の ViewModel (SettingsViewModel) から送る
    func send(_ action: TVSetupAction) {
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
        case .select(let host):
            guard let device = devices.first(where: { $0.host == host }) else { return }
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

    func confirmPairing() async {
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

    /// 入力した接続情報を保存する (設定の画面の「保存」から、SettingsViewModel が呼ぶ)
    func save() async {
        await remote.save(draft)
    }
}

// 設定の画面 (SettingsViewModel) が、CLI の操作「tv.〜」として見せる (部品なので、ここだけでは道を持たない)
extension TVSetupViewModel {
    var isBusy: Bool { work.isBusy }

    static var introspectionActions: [ActionDescription] {
        [
            ActionDescription("appear", "テレビの登録の画面を開いた (未設定なら探し始める)"),
            ActionDescription("setShowingManualEntry", "ユーザー名とパスワードの入力欄を開く・閉じる", parameters: ["isShowing": "true | false"]),
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
            ActionDescription("close", "テレビの登録の画面を閉じた (PIN を入れずに閉じたら、テレビの PIN 表示を消す)"),
        ]
    }

    func introspectionAction(_ name: String, _ arguments: [String: JSONValue]) throws -> TVSetupAction {
        switch name {
        case "appear": return .appear
        case "setShowingManualEntry": return .setShowingManualEntry(try arguments.bool("isShowing"))
        case "setHost": return .setHost(try arguments.string("host"))
        case "setUser": return .setUser(try arguments.string("user"))
        case "setPassword": return .setPassword(try arguments.string("password"))
        case "scan": return .scan
        case "select":
            let host = try arguments.string("host")
            guard devices.contains(where: { $0.host == host }) else {
                throw IntrospectionError.unavailable("テレビ \(host) は見つかっていません")
            }
            return .select(host)
        case "startPairing": return .startPairing
        case "setPIN": return .setPIN(try arguments.string("pin"))
        case "confirmPairing": return .confirmPairing
        case "cancelPairing": return .cancelPairing
        case "test": return .test
        case "close": return .close
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
