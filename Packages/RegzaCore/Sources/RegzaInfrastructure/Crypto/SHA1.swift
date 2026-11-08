import Foundation
import RegzaDomain

/// PIN 登録の鍵導出 (PBKDF2-HMAC-SHA1) 用。MD5 と同じく Android/Linux でも動くように自前で実装する。
enum SHA1 {
    static func digest(_ input: [UInt8]) -> [UInt8] {
        var message = input
        let bitLength = UInt64(input.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for i in (0..<8).reversed() { message.append(UInt8(truncatingIfNeeded: bitLength >> (8 * UInt64(i)))) }

        var h: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]

        for chunk in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 80)
            for i in 0..<16 {
                let j = chunk + i * 4
                w[i] = UInt32(message[j]) << 24 | UInt32(message[j + 1]) << 16
                    | UInt32(message[j + 2]) << 8 | UInt32(message[j + 3])
            }
            for i in 16..<80 { w[i] = rotate(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1) }

            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4]
            for i in 0..<80 {
                let f: UInt32, k: UInt32
                switch i {
                case 0..<20: f = (b & c) | (~b & d); k = 0x5A82_7999
                case 20..<40: f = b ^ c ^ d; k = 0x6ED9_EBA1
                case 40..<60: f = (b & c) | (b & d) | (c & d); k = 0x8F1B_BCDC
                default: f = b ^ c ^ d; k = 0xCA62_C1D6
                }
                let temp = rotate(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d
                d = c
                c = rotate(b, 30)
                b = a
                a = temp
            }
            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
        }

        return h.flatMap { word in
            (0..<4).reversed().map { UInt8(truncatingIfNeeded: word >> (8 * UInt32($0))) }
        }
    }

    static func hmac(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var key = key.count > 64 ? digest(key) : key
        key += [UInt8](repeating: 0, count: 64 - key.count)
        let inner = digest(key.map { $0 ^ 0x36 } + message)
        return digest(key.map { $0 ^ 0x5C } + inner)
    }

    /// RFC 8018 の PBKDF2 (PRF は HMAC-SHA1)
    static func pbkdf2(password: [UInt8], salt: [UInt8], iterations: Int, length: Int) -> [UInt8] {
        var result: [UInt8] = []
        var block: UInt32 = 1
        while result.count < length {
            var u = hmac(key: password, message: salt + (0..<4).reversed().map { UInt8(truncatingIfNeeded: block >> (8 * UInt32($0))) })
            var t = u
            for _ in 1..<max(1, iterations) {
                u = hmac(key: password, message: u)
                for i in t.indices { t[i] ^= u[i] }
            }
            result += t
            block += 1
        }
        return Array(result.prefix(length))
    }

    private static func rotate(_ value: UInt32, _ count: UInt32) -> UInt32 {
        value << count | value >> (32 - count)
    }
}
