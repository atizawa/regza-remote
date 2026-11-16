import Foundation
import RegzaStrings

/// テスト専用: アプリが頼っている Foundation の国際化の処理 (Android では ICU が受け持つ) を、アプリと同じ呼び方で動かし、
/// 結果を「名前: 値」の行で返す。APK の ICU はデータを絞って作り直している (scripts/slim-icu-data.swift) ので、
/// 端末のテスト (FoundationICUTest) が、絞る前の ICU と同じ結果になることを確かめる。
/// 本番の窓口 (RegzaAndroidBridge) には入れず、debug の APK にだけ入るテスト用の .so (RegzaFoundationCheck) から呼ぶ
public func regzaFoundationCheck() -> String {
    let date = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
    let tokyo = TimeZone(identifier: "Asia/Tokyo")
    let zone = tokyo ?? TimeZone(secondsFromGMT: 9 * 3600)!
    let locale = CoreStringTable.locale
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    // 日付の書式は DisplayText・GuideUseCase・GuideSearchViewModel と同じ (端末のタイムゾーンによらないよう、東京を指定する)
    let style = Date.FormatStyle(timeZone: zone).locale(locale)
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = zone
    formatter.dateFormat = CoreStrings.dateDayShort
    // テレビの古い API の応答 (RegzaResponseDecoding は UTF-8 → Shift_JIS → EUC-JP の順に読む)
    let shiftJIS = Data([0x93, 0xFA, 0x96, 0x7B, 0x8C, 0xEA, 0x82, 0xCC, 0x83, 0x65, 0x83, 0x4C, 0x83, 0x58, 0x83, 0x67])  // 日本語のテキスト
    // 番組検索の正規化 (ProgramSearch.normalize): 半角カナ・全角英数・全角空白・㈱・丸数字・大文字
    let text = "ｶﾞｷﾞ ＡＢＣ１２３　ひらがな㈱①abc"
    let lines: [(String, String)] = [
        ("timeZone", tokyo.map { "\($0.identifier) \($0.secondsFromGMT(for: date))" } ?? "nil"),
        ("weekday", "\(calendar.component(.weekday, from: date))"),
        ("startOfDay", "\(Int(calendar.startOfDay(for: date).timeIntervalSince1970))"),
        ("time", date.formatted(style.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))),
        ("day", date.formatted(style.month().day().weekday())),
        ("searchDay", date.formatted(style.month(.defaultDigits).day().weekday())),
        ("dayShort", formatter.string(from: date)),
        ("shiftJIS", String(data: shiftJIS, encoding: .shiftJIS) ?? "nil"),
        // Android の Foundation は、NFKC でも半角の濁点を前の文字と合わせない (カ + ゛ のまま) ので、アプリと同じく最後に NFC をかける
        ("nfkc", text.precomposedStringWithCompatibilityMapping.lowercased().precomposedStringWithCanonicalMapping),
        ("nfc", "ｽﾞ".precomposedStringWithCompatibilityMapping.precomposedStringWithCanonicalMapping),
        ("caseInsensitive", "\("Text".caseInsensitiveCompare("TEXT") == .orderedSame)"),
        ("trimming", "  テキスト  \n".trimmingCharacters(in: .whitespacesAndNewlines)),
    ]
    return lines.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
}
