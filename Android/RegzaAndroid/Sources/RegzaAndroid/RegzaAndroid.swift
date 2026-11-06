import RegzaCore

// Android アプリに見せる API。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core)。
// async の関数は Java の Future、throws の関数は Java の例外になる。
// 例外のメッセージは String(describing:) になるので、画面に出せる説明を持った RegzaAndroidError に包んで投げる

/// 画面に出せる説明を持ったエラー
public struct RegzaAndroidError: Error, CustomStringConvertible {
    public let description: String

    init(_ error: any Error) {
        description = (error as? RegzaError)?.errorDescription ?? String(describing: error)
    }

    init(message: String) {
        description = message
    }
}

/// テレビに登録した接続情報 (RegzaConnection と同じ中身)
public struct RegzaAndroidConnection {
    public var host: String
    public var user: String
    public var password: String

    public init(host: String, user: String, password: String) {
        self.host = host
        self.user = user
        self.password = password
    }
}

// MARK: - probe: テレビが応答するか、status.htm まで届くかを確かめる

public struct RegzaAndroidProbeResult {
    /// /public/feature に応答した
    public var found: Bool
    public var supportsPIN: Bool
    /// status.htm の結果。"ok"・"unauthorized" (認証を求められた)・エラーの説明
    public var status: String
}

/// user と password が空なら、認証を求められるところまでを確かめる
public func regzaProbe(host: String, user: String, password: String) async -> RegzaAndroidProbeResult {
    let device = await RegzaDiscovery.probe(host: host)
    let status: String
    do {
        _ = try await RegzaClient(connection: RegzaConnection(host: host, user: user, password: password)).status()
        status = "ok"
    } catch RegzaError.unauthorized {
        status = "unauthorized"
    } catch {
        status = RegzaAndroidError(error).description
    }
    return RegzaAndroidProbeResult(found: device != nil, supportsPIN: device?.supportsPIN ?? false, status: status)
}

// MARK: - PIN 登録

/// このアプリ用のユーザー ID を新しく作る (MAC アドレスの形)
public func regzaMakeUserID() -> String {
    RegzaPairing.makeUserID()
}

/// テレビに PIN を表示させてから確定するまでの 1 回の登録 (RegzaPairing)。
/// テレビから受け取った暗号化パスワードを持っているので、start から confirm まで同じものを使う
public final class RegzaAndroidPairing {
    private let session: RegzaPairing

    /// - Parameter user: このアプリ用のユーザー ID。登録し直すときも同じものを使い、テレビの登録が増えないようにする
    public init(host: String, user: String) {
        session = RegzaPairing(host: host, user: user)
    }

    /// テレビに PIN を表示させる
    public func start() async throws {
        do {
            try await session.start()
        } catch RegzaError.unsupported, RegzaError.httpStatus(404) {
            throw RegzaAndroidError(message: "この機種は PIN 登録に対応していません。")
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// PIN で登録を確定し、保存すべき接続情報を返す。PIN を打ち間違えたら、そのまま入力し直せる
    public func confirm(pin: String) async throws -> RegzaAndroidConnection {
        do {
            let connection = try await session.confirm(pin: pin)
            return RegzaAndroidConnection(host: connection.host, user: connection.user, password: connection.password)
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// テレビの PIN 表示を取り消す
    public func cancel() async {
        await session.cancel()
    }
}

// MARK: - リモコン

/// いま映っているもの (RegzaNowPlaying のうち画面に出すもの)
public struct RegzaAndroidNowPlaying {
    /// "broadcast" (放送)・"recorded" (録画の再生)・"external" (外部入力)・"standby" (待機中)・"unknown"
    public var kind: String
    public var channelName: String
    public var title: String
    /// 再生位置・放送開始からの経過 (秒)
    public var position: Int
    /// 番組の長さ (秒)
    public var duration: Int
    /// 再生位置が進んでいるか (再生中なら一時停止のボタンを出す)
    public var isAdvancing: Bool
}

/// 1 台のテレビのリモコン (RegzaRemote)。
/// 切り替えの最中に play/status を問い合わせないしくみは RegzaRemote の中にあるので、テレビごとに 1 つを使い回す
public final class RegzaAndroidRemote {
    private let remote: RegzaRemote

    public init(host: String, user: String, password: String) {
        remote = RegzaRemote(connection: RegzaConnection(host: host, user: user, password: password))
    }

    /// - Parameter key: RegzaKey の名前 ("power"・"volumeUp" など)
    public func send(key: String) async throws {
        guard let regzaKey = RegzaKey(name: key) else { throw RegzaAndroidError(message: "知らないキーです: \(key)") }
        do {
            try await remote.send(regzaKey)
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// いま映っているものを取り直す。アプリを開いている間は 2 秒ごとに呼ぶ (iOS 版と同じ)
    public func refresh() async throws -> RegzaAndroidNowPlaying {
        do {
            let nowPlaying = try await remote.refresh()
            return RegzaAndroidNowPlaying(
                kind: nowPlaying.kind.rawValue, channelName: nowPlaying.channelName, title: nowPlaying.title,
                position: nowPlaying.position, duration: nowPlaying.duration, isAdvancing: nowPlaying.isAdvancing
            )
        } catch {
            throw RegzaAndroidError(error)
        }
    }
}

/// ボタンに出す名前 (iOS 版と同じ)。知らないキーなら名前をそのまま返す
public func regzaKeyLabel(key: String) -> String {
    RegzaKey(name: key)?.label ?? key
}

extension RegzaKey {
    /// "power" のような名前から探す
    init?(name: String) {
        guard let key = Self.allCases.first(where: { String(describing: $0) == name }) else { return nil }
        self = key
    }
}
