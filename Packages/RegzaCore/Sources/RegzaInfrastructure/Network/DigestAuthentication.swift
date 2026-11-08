import Foundation
import RegzaDomain

/// HTTP Digest 認証 (RFC 2617) の `WWW-Authenticate` チャレンジ。
/// URLSession の認証チャレンジは Android の FoundationNetworking で Digest に対応していないため、
/// ヘッダーを自前で組み立てる。
struct DigestChallenge: Equatable, Sendable {
    var realm: String
    var nonce: String
    var qop: String?
    var opaque: String?
    var algorithm: String?

    init?(header: String) {
        let trimmed = header.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("digest ") else { return nil }
        let params = Self.parseParameters(String(trimmed.dropFirst("digest ".count)))
        guard let realm = params["realm"], let nonce = params["nonce"] else { return nil }
        self.realm = realm
        self.nonce = nonce
        // qop は "auth,auth-int" のように複数来ることがある。auth のみ対応
        self.qop = params["qop"].flatMap { qops in
            qops.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .contains("auth") ? "auth" : nil
        }
        self.opaque = params["opaque"]
        self.algorithm = params["algorithm"]
    }

    /// `Authorization` ヘッダーの値を作る
    func authorization(
        method: String, uri: String, user: String, password: String,
        nonceCount: Int, clientNonce: String
    ) -> String {
        let ha1 = MD5.hex("\(user):\(realm):\(password)")
        let ha2 = MD5.hex("\(method):\(uri)")
        let nc = String(format: "%08x", nonceCount)

        var fields = [
            "username=\"\(user)\"",
            "realm=\"\(realm)\"",
            "nonce=\"\(nonce)\"",
            "uri=\"\(uri)\"",
        ]
        if let qop {
            let response = MD5.hex("\(ha1):\(nonce):\(nc):\(clientNonce):\(qop):\(ha2)")
            fields += ["qop=\(qop)", "nc=\(nc)", "cnonce=\"\(clientNonce)\"", "response=\"\(response)\""]
        } else {
            fields.append("response=\"\(MD5.hex("\(ha1):\(nonce):\(ha2)"))\"")
        }
        if let opaque { fields.append("opaque=\"\(opaque)\"") }
        if let algorithm { fields.append("algorithm=\(algorithm)") }
        return "Digest " + fields.joined(separator: ", ")
    }

    /// `key="value", key=value` 形式をパースする
    static func parseParameters(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        var index = string.startIndex

        func skip(_ predicate: (Character) -> Bool) {
            while index < string.endIndex, predicate(string[index]) { index = string.index(after: index) }
        }

        while index < string.endIndex {
            skip { $0 == " " || $0 == "," }
            let keyStart = index
            skip { $0 != "=" && $0 != "," }
            let key = string[keyStart..<index].trimmingCharacters(in: .whitespaces).lowercased()
            guard index < string.endIndex, string[index] == "=" else { continue }
            index = string.index(after: index)

            var value = ""
            if index < string.endIndex, string[index] == "\"" {
                index = string.index(after: index)
                while index < string.endIndex, string[index] != "\"" {
                    if string[index] == "\\", string.index(after: index) < string.endIndex {
                        index = string.index(after: index)
                    }
                    value.append(string[index])
                    index = string.index(after: index)
                }
                if index < string.endIndex { index = string.index(after: index) }
            } else {
                let valueStart = index
                skip { $0 != "," }
                value = string[valueStart..<index].trimmingCharacters(in: .whitespaces)
            }
            if !key.isEmpty { result[key] = value }
        }
        return result
    }
}
