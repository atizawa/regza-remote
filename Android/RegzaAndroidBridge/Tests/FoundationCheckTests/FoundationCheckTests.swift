import Foundation
import FoundationCheck
import Testing

/// regzaFoundationCheck が、ICU をすべて持つ環境 (Apple) で返す値。Android の端末のテスト (FoundationICUTest) は、
/// データを絞って作り直した ICU でも同じ値になることを確かめる (期待する値は 2 か所で同じにする)
@Suite struct FoundationCheckTests {
    static let expected = """
        timeZone: Asia/Tokyo 32400
        weekday: 6
        startOfDay: 1799938800
        time: 17:00
        day: 1月15日(金)
        searchDay: 1/15(金)
        dayShort: 15(金)
        shiftJIS: 日本語のテキスト
        nfkc: ガギ abc123 ひらがな(株)1abc
        nfc: ズ
        caseInsensitive: true
        trimming: テキスト
        """

    @Test func matchesFullICU() {
        #expect(regzaFoundationCheck() == Self.expected)
    }
}
