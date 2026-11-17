import Foundation
import PresentationCore

/// 録画サーバーのアドレス (画面には分けたものと正しさを state で渡し、画面では計算しない)。保存するときは `192.168.0.2` か `192.168.0.2:40780` の 1 つの文字列にする
struct ServerAddress: Equatable, Sendable {
    var address: String
    /// 空なら標準のポート
    var port: String

    init(address: String, port: String) {
        self.address = address
        self.port = port
    }

    /// `host` か `host:port` を分ける
    init(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        if let colon = text.lastIndex(of: ":"), text[text.index(after: colon)...].allSatisfy(\.isNumber) {
            address = String(text[..<colon])
            port = String(text[text.index(after: colon)...])
        } else {
            address = text
            port = ""
        }
    }

    var combined: String {
        let address = address.trimmingCharacters(in: .whitespaces)
        let port = port.trimmingCharacters(in: .whitespaces)
        // アドレスより先にポートを入れても消えないよう、アドレスが空でもポートは残す
        return port.isEmpty ? address : "\(address):\(port)"
    }

    /// 保存する値。アドレスが空なら連携しない (ポートだけ入っていても空にする)
    var saved: String {
        address.trimmingCharacters(in: .whitespaces).isEmpty ? "" : combined
    }

    /// ポートが空か 1〜65535 の数字
    var isValid: Bool {
        let port = port.trimmingCharacters(in: .whitespaces)
        guard !port.isEmpty else { return true }
        return Int(port).map { (1...65535).contains($0) } ?? false
    }
}
