import Foundation
internal import RegzaStrings

/// UseCase が UI の型 (SharedModels) を作るときの表記。文言と同じく、選ばれている言語で書く
enum DisplayText {
    static var locale: Locale { CoreStringTable.locale }

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
        CoreStrings.timeRange(day(start), time(start), time(end))
    }
}
