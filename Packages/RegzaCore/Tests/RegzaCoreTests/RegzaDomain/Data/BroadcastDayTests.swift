import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct BroadcastDayTests {
    @Test func lateNightBelongsToPreviousDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 2026-11-05 (木) 01:30 は、11/4 (水) の 25 時
        let lateNight = Date(timeIntervalSince1970: 1_793_809_800)
        let wednesday4am = Date(timeIntervalSince1970: 1_793_732_400)
        #expect(BroadcastDay.start(of: lateNight, calendar: calendar) == wednesday4am)
        #expect(BroadcastDay.hour(of: lateNight, calendar: calendar) == 25)
        // 朝 4 時ちょうどは、その日の始まり
        #expect(BroadcastDay.start(of: wednesday4am, calendar: calendar) == wednesday4am)
        #expect(BroadcastDay.hour(of: wednesday4am, calendar: calendar) == 4)
    }
}
