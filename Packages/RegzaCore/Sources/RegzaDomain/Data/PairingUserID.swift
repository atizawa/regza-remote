import Foundation

/// PIN 登録でテレビに登録する、このアプリ用のユーザー ID (MAC アドレスの形 `AA-BB-CC-DD-EE-FF`)
public enum PairingUserID {
    /// ランダムなユーザー ID。マルチキャストにならないよう先頭バイトはローカル管理アドレスにする
    public static func make() -> String {
        var bytes = (0..<6).map { _ in UInt8.random(in: 0...255) }
        bytes[0] = (bytes[0] & 0xFC) | 0x02
        return bytes.map { String(format: "%02X", $0) }.joined(separator: "-")
    }
}
