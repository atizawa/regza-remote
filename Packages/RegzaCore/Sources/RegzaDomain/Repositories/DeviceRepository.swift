import Foundation

/// 同じネットワークの機器を探すことと、テレビへの PIN 登録
public protocol DeviceRepository: Sendable {
    /// 同じネットワークのテレビを、見つかった順に返す
    func devices() -> AsyncStream<RegzaDevice>
    /// テレビに PIN を表示させてから確定するまでの 1 回の登録
    func pairing(host: String, user: String) -> any PairingSession
    /// 同じネットワークで Mirakurun が動いているアドレス
    func findGuideServers() async -> [String]
    /// 同じネットワークで EPGStation が動いているアドレス
    func findStreamServers() async -> [String]
    /// そのアドレスで EPGStation が動いているか
    func isStreamServer(host: String) async -> Bool
}

/// テレビに PIN を表示させてから確定するまでの 1 回の登録。
/// テレビから受け取った暗号化パスワードを持っているので、start から confirm まで同じものを使う
public protocol PairingSession: Sendable {
    /// テレビに PIN を表示させる。PIN 登録に対応していない機種では `RegzaError.unsupported` か `httpStatus(404)`
    func start() async throws
    /// PIN で登録を確定し、保存すべき接続情報を返す
    func confirm(pin: String) async throws -> RegzaConnection
    /// テレビの PIN 表示を取り消す
    func cancel() async
}
