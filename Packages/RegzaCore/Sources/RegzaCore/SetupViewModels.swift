import Foundation
import Observation

/// テレビの設定の画面の ViewModel (iOS と Android で共有)。
/// 同じネットワークのテレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
@MainActor
@Observable
public final class TVSetupViewModel {
    public let remote: RemoteViewModel

    /// 入力中の接続情報 (保存するまで RemoteViewModel には入れない)
    public var draft: RegzaConnection
    /// このアプリ用のユーザー ID。手入力のユーザー名は他のツールと共有している
    /// かもしれないので使い回さない (同じ ID で登録し直すと、前のパスワードが無効になる)
    public let pairingUserID: String

    public init(remote: RemoteViewModel) {
        self.remote = remote
        draft = remote.connection
        pairingUserID = remote.pairingUserID()
    }

    // MARK: - テレビを探す

    /// 見つかったテレビ
    public private(set) var devices: [RegzaDevice] = []
    public private(set) var isScanning = false
    public private(set) var scanMessage: String?

    /// 未設定なら、画面を開いたときに探し始める
    public var shouldScanOnOpen: Bool { !remote.connection.isConfigured && devices.isEmpty }

    public func scan() async {
        isScanning = true
        defer { isScanning = false }
        scanMessage = nil
        devices = []
        for await device in RegzaDiscovery.devices() {
            devices.append(device)
            // 1 台目は選んでおく。登録は利用者がボタンを押してから
            if devices.count == 1, draft.host.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.host = device.host
            }
        }
        if devices.isEmpty {
            scanMessage = "見つかりませんでした。テレビの電源が入っているか、iPhone の「設定」→「プライバシーとセキュリティ」→「ローカルネットワーク」でこのアプリが許可されているか確認してください。"
        }
    }

    /// 未登録なら、選んだテレビにそのまま PIN を表示させる。
    /// 登録済みなら IP アドレスだけ変える (DHCP でアドレスが変わった場合など)
    public func select(_ device: RegzaDevice) async {
        draft.host = device.host
        if device.supportsPIN, !isRegistered { await startPairing() }
    }

    public func isSelected(_ device: RegzaDevice) -> Bool { draft.host == device.host }

    // MARK: - PIN で登録

    /// PIN 登録中 (テレビに PIN が表示されている間) のセッション
    @ObservationIgnored private var pairing: RegzaPairing?
    /// テレビに PIN が表示されていて、入力を待っている
    public private(set) var isWaitingForPIN = false
    public var pin = ""
    public private(set) var isPairing = false
    public private(set) var pairingMessage: String?
    /// ユーザー名とパスワードの入力欄を開いているか (PIN 登録に対応していない機種なら開く)
    public var isShowingManualEntry = false

    /// このアプリの ID で登録済みか
    public var isRegistered: Bool {
        !pairingUserID.isEmpty && draft.user == pairingUserID && !draft.password.isEmpty
    }

    public func startPairing() async {
        isPairing = true
        defer { isPairing = false }
        pairingMessage = nil
        // 登録し直すときはアプリの ID を使い回し、テレビの登録機器が増えないようにする
        let session = RegzaPairing(host: draft.host, user: pairingUserID)
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

    /// PIN で登録を確定して保存する。保存できたら true (画面を閉じる)
    public func confirmPairing() async -> Bool {
        guard let pairing else { return false }
        isPairing = true
        defer { isPairing = false }
        do {
            draft = try await pairing.confirm(pin: pin)
            self.pairing = nil
            isWaitingForPIN = false
            await remote.save(draft)
            return true
        } catch {
            // PIN の打ち間違いはそのまま入力し直せるようにする
            pairingMessage = error.localizedDescription
            return false
        }
    }

    public func cancelPairing() async {
        await pairing?.cancel()
        pairing = nil
        isWaitingForPIN = false
        pin = ""
        pairingMessage = nil
    }

    /// 画面を閉じたとき。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
    public func close() {
        guard let pairing else { return }
        self.pairing = nil
        isWaitingForPIN = false
        Task { await pairing.cancel() }
    }

    // MARK: - 接続テスト

    public private(set) var isTesting = false
    public private(set) var testResult: String?

    public func test() async {
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

    /// 一覧に出すテレビの状態。操作できるときはアドレスだけ、注意が要るときだけ目立たせる
    public var status: (text: String, needsAttention: Bool) {
        let host = draft.host.trimmingCharacters(in: .whitespaces)
        if host.isEmpty { return ("未設定", true) }
        // PIN の登録でも手入力でも、パスワードがなければ操作できない
        if draft.password.isEmpty { return ("PIN の登録が必要", true) }
        return (host, false)
    }

    /// 保存できるか (アドレスがあり、PIN の入力を待っていない)
    public var canSave: Bool { draft.isConfigured && !isWaitingForPIN }

    public func save() async {
        await remote.save(draft)
    }
}

/// 録画サーバー (番組表の Mirakurun・ライブ視聴の EPGStation) の設定の画面の ViewModel (iOS と Android で共有)
@MainActor
@Observable
public final class ServerSetupViewModel {
    public let guide: GuideViewModel
    public let stream: StreamViewModel

    /// 入力中のアドレス (`192.168.0.2` か `192.168.0.2:40772`)
    public var guideHost: String
    public var streamHost: String

    public init(guide: GuideViewModel, stream: StreamViewModel) {
        self.guide = guide
        self.stream = stream
        guideHost = guide.guideHost
        streamHost = stream.streamHost
    }

    public enum Server: Sendable {
        case guide, stream
    }

    public private(set) var guideHosts: [String] = []
    public private(set) var isScanningGuide = false
    public private(set) var guideMessage: String?
    public private(set) var streamHosts: [String] = []
    public private(set) var isScanningStream = false
    public private(set) var streamMessage: String?

    /// Mirakurun のアドレスが入っているか (保存前の入力も含む)。EPGStation は Mirakurun から放送を受け取るので、
    /// Mirakurun を入れてから設定できるようにする
    public var hasGuideDraft: Bool { !ServerAddress(guideHost).saved.isEmpty }

    /// 一覧に出す状態 (アドレスか「未設定」)
    public func status(of server: Server) -> String {
        let host = ServerAddress(server == .guide ? guideHost : streamHost).saved
        return host.isEmpty ? "未設定" : host
    }

    /// 保存済みで、連携を解除できるか
    public func isLinked(_ server: Server) -> Bool {
        !(server == .guide ? guide.guideHost : stream.streamHost).isEmpty
    }

    /// 入力したポートが正しいか
    public var isValid: Bool { ServerAddress(guideHost).isValid && ServerAddress(streamHost).isValid }

    public func scanGuide() async {
        isScanningGuide = true
        defer { isScanningGuide = false }
        guideMessage = nil
        guideHosts = await Mirakurun.find()
        if let first = guideHosts.first, guideHost.trimmingCharacters(in: .whitespaces).isEmpty {
            guideHost = first
        }
        if guideHosts.isEmpty {
            guideMessage = "見つかりませんでした。Mirakurun が動いているか、ポート \(Mirakurun.defaultPort) で待ち受けているか確認してください。"
        }
    }

    public func scanStream() async {
        isScanningStream = true
        defer { isScanningStream = false }
        streamMessage = nil
        streamHosts = await EPGStation.find()
        if let first = streamHosts.first, streamHost.trimmingCharacters(in: .whitespaces).isEmpty {
            streamHost = first
        }
        if streamHosts.isEmpty {
            streamMessage = "見つかりませんでした。EPGStation が動いているか、ポート \(EPGStation.defaultPort) で待ち受けているか確認してください。"
        }
    }

    /// Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
    public func suggestStreamHost(transport: any HTTPTransport = RegzaHTTP.transport) async {
        guard streamHost.trimmingCharacters(in: .whitespaces).isEmpty, streamHosts.isEmpty else { return }
        // Mirakurun のアドレスからポートを除いたもの
        let server = ServerAddress(guideHost).address
        guard !server.isEmpty, await EPGStation(host: server, timeout: 3, transport: transport).isAvailable() else { return }
        streamHosts = [server]
        streamHost = server
        streamMessage = "Mirakurun と同じサーバーで EPGStation が見つかりました。よければ「保存」を押してください。"
    }

    /// 連携をやめる。すぐにアドレスを消して反映する。EPGStation だけでは使えないので、番組表を外したら一緒に外す
    public func unlink(_ server: Server) async {
        if server == .guide {
            guideHost = ""
            guideHosts = []
            await guide.saveGuideHost("")
        }
        streamHost = ""
        streamHosts = []
        stream.saveStreamHost("")
    }

    /// 解除するか確かめるときの見出しと説明
    public func unlinkQuestion(_ server: Server) -> (title: String, message: String) {
        switch server {
        case .guide:
            ("Mirakurun との連携を解除しますか？",
             "番組名・番組表・番組表からの録画予約が使えなくなります。ライブ視聴（EPGStation）の連携も解除されます。")
        case .stream:
            ("EPGStation との連携を解除しますか？", "アプリでのライブ視聴が使えなくなります。")
        }
    }

    public func save() async {
        await guide.saveGuideHost(ServerAddress(guideHost).saved)
        stream.saveStreamHost(ServerAddress(streamHost).saved)
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
