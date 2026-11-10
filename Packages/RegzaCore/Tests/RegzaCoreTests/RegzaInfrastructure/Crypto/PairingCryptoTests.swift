import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct PairingCryptoTests {
    func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    @Test func sha1() {
        #expect(hex(SHA1.digest(Array("abc".utf8))) == "a9993e364706816aba3e25717850c26c9cd0d89d")
        #expect(hex(SHA1.digest([])) == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    // RFC 6070
    @Test func pbkdf2() {
        let password = Array("password".utf8)
        let salt = Array("salt".utf8)
        #expect(hex(SHA1.pbkdf2(password: password, salt: salt, iterations: 1, length: 20)) == "0c60c80f961f0e71f3a9b524af6012062fe037a6")
        #expect(
            hex(SHA1.pbkdf2(password: password, salt: salt, iterations: 4096, length: 20)) == "4b007901b765489abead49d926f721d065a429c1")
    }

    // FIPS-197 C.1
    @Test func aesBlock() throws {
        let key = try #require([UInt8](hex: "000102030405060708090a0b0c0d0e0f"))
        let block = try #require([UInt8](hex: "69c4e0d86a7b0430d8cdb78070b4c55a"))
        let aes = try #require(AES128(key: key))
        let plain = aes.decryptBlock(block)
        #expect(hex(plain) == "00112233445566778899aabbccddeeff")
    }

    /// Python の hashlib.pbkdf2_hmac と openssl enc -aes-128-cbc で作った値
    @Test func decryptsPassword() {
        let encrypted = "c4909140d2f5f81261a1bd1d715fdc2c53ce4586b6d6dde3f16390198fee8f2c"
        #expect(RegzaPairing.decryptPassword(encrypted, pin: "1234", salt: "abcdef0123456789") == "Ab3$xyZ9-Test.Password_01")
        #expect(RegzaPairing.decryptPassword(encrypted, pin: "1235", salt: "abcdef0123456789") == nil)
    }

    @Test func userID() {
        let parts = PairingUserID.make().split(separator: "-")
        #expect(parts.count == 6)
        #expect(parts.allSatisfy { $0.count == 2 && UInt8($0, radix: 16) != nil })
        #expect(PairingUserID.make() != PairingUserID.make())
    }
}
