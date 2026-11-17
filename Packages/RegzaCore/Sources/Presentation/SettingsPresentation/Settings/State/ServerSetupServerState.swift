import Foundation
import PresentationCore

/// 1 つの録画サーバーの設定
public struct ServerSetupServerState: Equatable, Sendable {
    /// 入力中のアドレス (`192.168.0.2` か `192.168.0.2:40772`)
    public var host: String
    /// 入力中のアドレスの、ポートを除いた部分 (アドレスの欄に出す)
    public var address: String
    /// 入力中のポート。空なら標準のポート (defaultPort) を使う (ポートの欄に出す)
    public var port: String
    /// ポートが空か 1〜65535 の数字 (違えば、標準のポートを添えて説明を出す)
    public var isPortValid: Bool
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
