import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct MD5Tests {
    @Test func knownVectors() {
        #expect(MD5.hex("") == "d41d8cd98f00b204e9800998ecf8427e")
        #expect(MD5.hex("The quick brown fox jumps over the lazy dog") == "9e107d9d372bb6826bd81d3542a419d6")
        #expect(MD5.hex(String(repeating: "a", count: 1000)) == "cabe45dcc9ae5b66ba86600cca6b8ba8")
    }
}
