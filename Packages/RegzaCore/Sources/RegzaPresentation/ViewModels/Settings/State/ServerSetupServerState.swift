public import Foundation

/// 1 つの録画サーバーの設定
public struct ServerSetupServerState: Equatable, Sendable {
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
