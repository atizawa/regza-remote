import Foundation
import RegzaDomain

/// PIN 登録で受け取るパスワードの復号用 AES-128 (復号のみ)。CommonCrypto が無い環境でも動くように自前で実装する。
struct AES128 {
    private static let sbox: [UInt8] = {
        // GF(2^8) の逆元とアフィン変換から S-box を作る (FIPS-197 5.1.1)
        func rotl(_ x: UInt8, _ n: UInt8) -> UInt8 { x << n | x >> (8 - n) }
        var box = [UInt8](repeating: 0, count: 256)
        var p: UInt8 = 1, q: UInt8 = 1
        repeat {
            p = p ^ (p << 1) ^ (p & 0x80 != 0 ? 0x1B : 0)
            q ^= q << 1
            q ^= q << 2
            q ^= q << 4
            if q & 0x80 != 0 { q ^= 0x09 }
            box[Int(p)] = q ^ rotl(q, 1) ^ rotl(q, 2) ^ rotl(q, 3) ^ rotl(q, 4) ^ 0x63
        } while p != 1
        box[0] = 0x63
        return box
    }()

    private static let inverseSbox: [UInt8] = {
        var box = [UInt8](repeating: 0, count: 256)
        for (i, value) in sbox.enumerated() { box[Int(value)] = UInt8(i) }
        return box
    }()

    /// 11 ラウンド分の鍵 (16 バイト × 11)
    private let roundKeys: [UInt8]

    init?(key: [UInt8]) {
        guard key.count == 16 else { return nil }
        var words = key
        var rcon: UInt8 = 1
        while words.count < 176 {
            var t = Array(words[(words.count - 4)...])
            if words.count % 16 == 0 {
                t = [t[1], t[2], t[3], t[0]].map { Self.sbox[Int($0)] }
                t[0] ^= rcon
                rcon = Self.multiply(rcon, 2)
            }
            for byte in t { words.append(words[words.count - 16] ^ byte) }
        }
        roundKeys = words
    }

    /// CBC モードで復号し、PKCS#7 のパディングを取り除く。パディングが不正なら nil
    func decryptCBC(_ data: [UInt8], iv: [UInt8] = [UInt8](repeating: 0, count: 16)) -> [UInt8]? {
        guard !data.isEmpty, data.count % 16 == 0, iv.count == 16 else { return nil }
        var result: [UInt8] = []
        var previous = iv
        for start in stride(from: 0, to: data.count, by: 16) {
            let block = Array(data[start..<start + 16])
            result += zip(decryptBlock(block), previous).map { $0 ^ $1 }
            previous = block
        }
        guard let padding = result.last, (1...16).contains(padding),
              result.suffix(Int(padding)).allSatisfy({ $0 == padding })
        else { return nil }
        return Array(result.dropLast(Int(padding)))
    }

    func decryptBlock(_ block: [UInt8]) -> [UInt8] {
        var state = addRoundKey(block, round: 10)
        for round in (0..<10).reversed() {
            // 行を右にずらし (InvShiftRows)、S-box を戻す (InvSubBytes)。state は列優先
            state = (0..<16).map { i in
                let row = i % 4, column = i / 4
                return Self.inverseSbox[Int(state[row + 4 * ((column - row + 4) % 4)])]
            }
            state = addRoundKey(state, round: round)
            if round > 0 { state = Self.inverseMixColumns(state) }
        }
        return state
    }

    private func addRoundKey(_ state: [UInt8], round: Int) -> [UInt8] {
        (0..<16).map { state[$0] ^ roundKeys[round * 16 + $0] }
    }

    private static func inverseMixColumns(_ state: [UInt8]) -> [UInt8] {
        var result = state
        for column in 0..<4 {
            let a = Array(state[column * 4..<column * 4 + 4])
            for row in 0..<4 {
                result[column * 4 + row] = multiply(a[row], 14) ^ multiply(a[(row + 1) % 4], 11)
                    ^ multiply(a[(row + 2) % 4], 13) ^ multiply(a[(row + 3) % 4], 9)
            }
        }
        return result
    }

    private static func multiply(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var a = a, b = b, result: UInt8 = 0
        while b != 0 {
            if b & 1 != 0 { result ^= a }
            a = (a << 1) ^ (a & 0x80 != 0 ? 0x1B : 0)
            b >>= 1
        }
        return result
    }
}
