import RegzaCore

// Android アプリに見せる API。swift-java がここの public な型と関数から Java のクラスを作る
// (Java のパッケージは com.example.regzaremote.core)。RegzaKey・RegzaNowPlaying・RegzaConnection は
// RegzaCore の型をそのまま使う (Java のクラスは RegzaCoreJava で作る)。
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
    public func confirm(pin: String) async throws -> RegzaConnection {
        do {
            return try await session.confirm(pin: pin)
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

/// 1 台のテレビのリモコン (RegzaRemote)。
/// 切り替えの最中に play/status を問い合わせないしくみは RegzaRemote の中にあるので、テレビごとに 1 つを使い回す
public final class RegzaAndroidRemote {
    private let remote: RegzaRemote

    public init(host: String, user: String, password: String) {
        remote = RegzaRemote(connection: RegzaConnection(host: host, user: user, password: password))
    }

    public func send(key: RegzaKey) async throws {
        do {
            try await remote.send(key)
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// テレビに登録されているチャンネル
    public func channels() async throws -> [RegzaChannel] {
        do {
            return try await remote.client.channels()
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// 選局して、選んだチャンネルに切り替わったものとしての「いま映っているもの」を返す
    /// (切り替えの最中は問い合わせないので、番組名などは落ち着いてから refresh で取り直す)
    public func tune(channel: RegzaChannel) async throws -> RegzaNowPlaying {
        do {
            try await remote.tune(to: channel)
            return await remote.nowPlaying ?? RegzaNowPlaying(kind: .broadcast, channelName: channel.name, channelCode: channel.code)
        } catch {
            throw RegzaAndroidError(error)
        }
    }

    /// いま映っているものを取り直す。アプリを開いている間は 2 秒ごとに呼ぶ (iOS 版と同じ)
    public func refresh() async throws -> RegzaNowPlaying {
        do {
            return try await remote.refresh()
        } catch {
            throw RegzaAndroidError(error)
        }
    }
}

// MARK: - チャンネル一覧

/// チャンネル一覧に出すチャンネル (RegzaChannel.channelList)。
/// 番組名を返す関数を引数に取る形は Java のクラスにならないので、ここから呼ぶ。Android はまだ番組表がないので番組名は渡さない
public func regzaChannelList(_ channels: [RegzaChannel], band: RegzaChannel.Band?, nowPlayingChannelCode: String) -> [RegzaChannel] {
    RegzaChannel.channelList(channels, in: band, nowPlayingChannelCode: nowPlayingChannelCode)
}
