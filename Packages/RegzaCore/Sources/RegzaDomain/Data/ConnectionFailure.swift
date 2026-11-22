import Foundation

/// 通信が返事を受け取れなかった理由の種類。通信 (OS ごとの実装) は種類だけを伝え、文言は共有の Swift が決める
/// (OS の文言は言語や言い方が OS ごとに違い、接続先のアドレスが入ることもあるので画面に出さない)
public enum ConnectionFailure: String, Equatable, Sendable, CaseIterable {
    /// 接続先が見つからない・つながらない
    case cannotConnect = "cannot_connect"
    /// 決めた時間までに返事がない
    case timedOut = "timed_out"
    /// 接続先の証明書を確かめられない
    case certificate
    /// 端末がネットワークにつながっていない
    case offline
    /// 通信を取り消した
    case cancelled
    /// 返事の形が正しくない
    case invalidResponse = "invalid_response"
    /// そのほか
    case other
}
