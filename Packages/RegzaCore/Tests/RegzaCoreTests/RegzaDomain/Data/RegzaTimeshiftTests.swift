import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct TimeshiftTests {
    // テレビの設定「平日 19 時〜翌 1 時、土日 8 時〜翌 1 時」のときの値
    let json = """
        {"status":0,"timeshift_enabled":"true","target_channel":["JP-G00000001"],"active_time_list":[\
        {"active_time":"00f80001","day_of_week":"mon"},{"active_time":"00f80001","day_of_week":"tue"},\
        {"active_time":"00f80001","day_of_week":"wed"},{"active_time":"00f80001","day_of_week":"thu"},\
        {"active_time":"00f80001","day_of_week":"fri"},{"active_time":"00ffff01","day_of_week":"sat"},\
        {"active_time":"00ffff01","day_of_week":"sun"}]}
        """

    func jst(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    @Test func startOverOnlyWhileRecording() throws {
        let settings = try JSONDecoder().decode(RegzaTimeshiftSettings.self, from: Data(json.utf8))
        let channel = "JP-G00000001"
        // 2026-11-04 は水曜日
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 21:00"), now: jst("2026-11-04 21:30")))
        // 録画は 19 時からなので、18:30 に始まった番組は最初からは見られない
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 18:30"), now: jst("2026-11-04 19:30")))
        // 平日の昼は録画していない
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 12:00"), now: jst("2026-11-04 12:10")))
        // 翌日 0 時台まではつながっている
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-04 23:30"), now: jst("2026-11-05 00:40")))
        #expect(!settings.canStartOver(channelCode: channel, programStart: jst("2026-11-05 00:30"), now: jst("2026-11-05 01:10")))
        // 土曜は 8 時から
        #expect(settings.canStartOver(channelCode: channel, programStart: jst("2026-11-07 09:00"), now: jst("2026-11-07 09:20")))
        // 対象でない局
        #expect(!settings.canStartOver(channelCode: "JP-G00000002", programStart: jst("2026-11-04 21:00"), now: jst("2026-11-04 21:30")))
    }
}
