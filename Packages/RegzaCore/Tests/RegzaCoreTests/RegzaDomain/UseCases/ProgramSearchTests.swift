import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct ProgramSearchTests {
    func program(_ id: Int, _ name: String, start: String, minutes: Int = 30, genre: Int = 1,
                 cast: String = "") throws -> MirakurunProgram {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let startAt = Int(formatter.date(from: start)!.timeIntervalSince1970 * 1000)
        let json = """
            {"id":\(id),"eventId":\(id),"networkId":1,"serviceId":1,"startAt":\(startAt),"duration":\(minutes * 60_000),\
            "name":"\(name)","description":"","extended":{"出演者":"\(cast)"},"genres":[{"lv1":\(genre)}]}
            """
        return try JSONDecoder().decode(MirakurunProgram.self, from: Data(json.utf8))
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    // 2026-11-04 (水) 12:00 に探す
    let now = Date(timeIntervalSince1970: 1_793_761_200)

    @Test func expandedTermsMatchAnyAndExplainWhy() throws {
        let programs = [
            try program(1, "ドラマ　港の灯", start: "2026-11-05 21:00", genre: 3, cast: "テスト太郎，見本花子"),
            try program(2, "クイズ番組", start: "2026-11-05 19:00", genre: 5, cast: "例示次郎"),
            try program(3, "ニュース", start: "2026-11-05 18:00", genre: 0),
        ]
        // AI が「グループ名」を、メンバーの名前に広げた想定
        let query = ProgramSearchQuery(keywordGroups: [["見本グループ", "テスト太郎", "例示次郎"]])
        let found = ProgramSearchIndex(programs).search(query, now: now, calendar: calendar)
        #expect(found.map(\.program.id) == [2, 1])
        #expect(found.map(\.matches) == [
            [.init(term: "例示次郎", field: .cast)], [.init(term: "テスト太郎", field: .cast)],
        ])
    }

    @Test func normalizesWidthKanaAndCase() {
        // 検索はバイト列で比べるので、String の == (正準等価) ではなくバイト列で確かめる
        let bytes = { (text: String) in Array(ProgramSearch.normalize(text).utf8) }
        #expect(bytes("ｶﾞﾝﾀﾞﾑ") == bytes("がんだむ"))
        #expect(bytes("ｸｲｽﾞ") == bytes("クイズ"))
        #expect(bytes("ＡＢＣ　１２３") == Array("abc123".utf8))
        #expect(bytes("サッカー") == bytes("ｻｯｶｰ"))
    }

    @Test func filtersByDayHourAndGenre() throws {
        let programs = [
            try program(1, "サッカー　日本代表戦", start: "2026-11-05 19:00", genre: 1),
            try program(2, "ニュース", start: "2026-11-05 19:00", genre: 0),
            try program(3, "深夜のサッカー", start: "2026-11-06 01:00", genre: 1),
            try program(4, "サッカー中継", start: "2026-11-04 10:00", genre: 1),  // もう終わっている
        ]
        // 明日の夜のスポーツ。深夜 1 時は明日の 25 時として扱う。全角半角・ひらがなカタカナは区別しない
        let query = ProgramSearchQuery(keywordGroups: [["ｻｯｶｰ"]], genres: [1], dayOffset: 1, startHour: 18, endHour: 28)
        let index = ProgramSearchIndex(programs)
        #expect(index.search(query, now: now, calendar: calendar).map(\.program.id) == [1, 3])
        // 打った言葉は、すべて含むものだけ
        let plain = index.search(ProgramSearchQuery(text: "さっかー 日本"), now: now, calendar: calendar)
        #expect(plain.map(\.program.id) == [1])
        #expect(plain.first?.matches.map(\.field) == [.title, .title])
    }
}

@Suite struct ProgramSearchParsingTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    // 2026-11-04 (水) 12:00
    let now = Date(timeIntervalSince1970: 1_793_761_200)

    func parse(_ text: String) -> ProgramSearchQuery {
        ProgramSearchQuery(parsing: text, now: now, calendar: calendar)
    }

    @Test func readsDayHoursAndGenre() {
        #expect(parse("明日の夜のサッカー") == ProgramSearchQuery(
            keywordGroups: [["サッカー"]], dayOffset: 1, startHour: 18, endHour: 28))
        #expect(parse("土曜のアニメ") == ProgramSearchQuery(genres: [7], dayOffset: 3))
        #expect(parse("２１時からのドラマ") == ProgramSearchQuery(genres: [3], startHour: 21))
        #expect(parse("今夜 映画") == ProgramSearchQuery(genres: [6], dayOffset: 0, startHour: 18, endHour: 28))
        #expect(parse("11/7 深夜1時") == ProgramSearchQuery(dayOffset: 3, startHour: 25, endHour: 26))
        #expect(parse("明日の番組") == ProgramSearchQuery(dayOffset: 1))
    }

    @Test func leavesWordsThatOnlyContainConditions() {
        #expect(parse("朝ドラ") == ProgramSearchQuery(keywordGroups: [["朝ドラ"]]))
        #expect(parse("大河ドラマ") == ProgramSearchQuery(keywordGroups: [["大河ドラマ"]]))
        #expect(parse("あすなろ") == ProgramSearchQuery(keywordGroups: [["あすなろ"]]))
        #expect(parse("見本太郎 例示") == ProgramSearchQuery(keywordGroups: [["見本太郎"], ["例示"]]))
    }
}
