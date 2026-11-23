import Foundation
public import Observation
public import PresentationCore
package import RegzaDomain
import RegzaStrings

/// 設定の中のテレビの登録 (SettingsViewModel の部品)。
/// 同じネットワークのテレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
@MainActor
@Observable
public final class TVSetupViewModel {
    public let remoteViewModel: RemoteViewModel
    private let setupUseCase: any SetupUseCaseProtocol
    /// このアプリ用のユーザー ID。手入力のユーザー名は他のツールと共有している
    /// かもしれないので使い回さない (同じ ID で登録し直すと、前のパスワードが無効になる)
    public let pairingUserID: String

    package init(remoteViewModel: RemoteViewModel, setupUseCase: any SetupUseCaseProtocol) {
        self.remoteViewModel = remoteViewModel
        self.setupUseCase = setupUseCase
        draft = remoteViewModel.connection
        pairingUserID = remoteViewModel.pairingUserID()
    }

    /// 画面に出すもの
    public typealias State = TVSetupState

    /// 一覧に出すテレビの状態
    public typealias Status = TVSetupStatus

    private var draft: ConnectionItem
    private var devices: [DeviceItem] = []
    private var isScanning = false
    private var scanMessage: String?
    /// PIN 登録中 (テレビに PIN が表示されている間) のセッション
    @ObservationIgnored private var pairing: (any PairingRegistration)?
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
            if !remoteViewModel.connection.isConfigured && devices.isEmpty && !isScanning { work.run { await self.scan() } }
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
        if host.isEmpty { return Status(text: CoreStrings.setupNotConfigured, needsAttention: true) }
        // PIN の登録でも手入力でも、パスワードがなければ操作できない
        if draft.password.isEmpty { return Status(text: CoreStrings.tvPinRequired, needsAttention: true) }
        return Status(text: host, needsAttention: false)
    }

    // MARK: - テレビを探す

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        scanMessage = nil
        devices = []
        for await device in setupUseCase.findTVs() {
            devices.append(device)
            // 1 台目は選んでおく。登録は利用者がボタンを押してから
            if devices.count == 1, draft.host.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.host = device.host
            }
        }
        if devices.isEmpty {
            #if os(iOS)
            scanMessage = CoreStrings.tvScanNotFoundIos
            #else
            scanMessage = CoreStrings.tvScanNotFound
            #endif
        }
    }

    // MARK: - PIN で登録

    private func startPairing() async {
        isPairing = true
        defer { isPairing = false }
        pairingMessage = nil
        // 登録し直すときはアプリの ID を使い回し、テレビの登録機器が増えないようにする
        let session = setupUseCase.pairing(host: draft.host, user: pairingUserID)
        do {
            try await session.start()
            pairing = session
            pin = ""
            isWaitingForPIN = true
        } catch {
            let error = RegzaError(error)
            pairingMessage = ErrorMessage.text(error, in: .pairing)
            // PIN 登録に対応していない機種は、ユーザー名とパスワードを入れてもらう
            if error.isUnsupported { isShowingManualEntry = true }
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
            await remoteViewModel.save(draft)
            hasRegistered = true
        } catch {
            // PIN の打ち間違いはそのまま入力し直せるようにする
            pairingMessage = ErrorMessage.text(error, in: .pairing)
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
        switch await remoteViewModel.testConnection(draft) {
        case .success(let nowPlaying):
            let detail = nowPlaying.title.isEmpty ? nowPlaying.channelName : nowPlaying.title
            testResult = detail.isEmpty ? CoreStrings.tvConnected : CoreStrings.tvConnectedDetail(detail)
        case .failure(let error):
            testResult = ErrorMessage.text(error)
        }
    }

    // MARK: - 保存

    /// 入力した接続情報を保存する (設定の画面の「保存」から、SettingsViewModel が呼ぶ)
    func save() async {
        await remoteViewModel.save(draft)
    }
}

// 設定の画面 (SettingsViewModel) が、CLI の操作「tv.〜」として見せる (部品なので、ここだけでは道を持たない)
extension TVSetupViewModel {
    var isBusy: Bool { work.isBusy }

    /// 設定の操作の表に入れる、この部品の操作 (名前の前に tv. を付けて見せる)
    var introspectionTable: [IntrospectionAction<TVSetupAction>] {
        [
            IntrospectionAction("appear", "テレビの登録の画面を開いた (未設定なら探し始める)", .appear),
            IntrospectionAction("setShowingManualEntry", "ユーザー名とパスワードの入力欄を開く・閉じる", .bool("isShowing", "true | false")) {
                .setShowingManualEntry($0)
            },
            IntrospectionAction("setHost", "テレビの IP アドレスを入れる", .string("host", "IP アドレス")) { .setHost($0) },
            IntrospectionAction("setUser", "ユーザー名を入れる (PIN 登録に対応していない機種)", .string("user", "ユーザー名")) { .setUser($0) },
            IntrospectionAction("setPassword", "パスワードを入れる (PIN 登録に対応していない機種)", .string("password", "パスワード")) {
                .setPassword($0)
            },
            IntrospectionAction("scan", "同じネットワークのテレビを探す", .scan),
            IntrospectionAction("select", "見つかったテレビを選ぶ (未登録なら PIN を表示させる)", .string("host", "devices の host")) { host in
                guard self.devices.contains(where: { $0.host == host }) else {
                    throw IntrospectionError.unavailable("テレビ \(host) は見つかっていません")
                }
                return .select(host)
            },
            IntrospectionAction("startPairing", "テレビに PIN を表示させる", .startPairing),
            IntrospectionAction("setPIN", "テレビに表示された PIN を入れる", .string("pin", "PIN")) { .setPIN($0) },
            IntrospectionAction("confirmPairing", "PIN で登録して保存する", .confirmPairing),
            IntrospectionAction("cancelPairing", "PIN の登録をやめる", .cancelPairing),
            IntrospectionAction("test", "入力した接続情報でつながるか試す", .test),
            IntrospectionAction("close", "テレビの登録の画面を閉じた (PIN を入れずに閉じたら、テレビの PIN 表示を消す)", .close),
        ]
    }
}
