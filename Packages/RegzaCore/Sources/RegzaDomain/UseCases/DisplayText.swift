import Foundation

/// UseCase が UI の型 (SharedModels) を作るときの表記。アプリは日本語だけなので、OS の言語によらず日本語で書く
enum DisplayText {
    static let locale = Locale(identifier: "ja_JP")

    /// 「13:00」
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// 「11月7日(土)」
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month().day().weekday())
    }

    /// 「11月7日(土) 13:00 〜 13:45」
    static func range(_ start: Date, _ end: Date) -> String {
        "\(day(start)) \(time(start)) 〜 \(time(end))"
    }
}
