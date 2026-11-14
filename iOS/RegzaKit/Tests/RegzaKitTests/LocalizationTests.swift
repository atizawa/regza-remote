import Foundation
import Localization
import Testing

@Suite struct LocalizationTests {
    @Test func readsCatalogFromLocalizationPackage() {
        #expect(AppStrings.settingsTitle == "設定")
        #expect(AppStrings.commonClose == "閉じる")
    }

    @Test func formatsArgumentsAndRetainsNewlines() {
        #expect(AppStrings.serverSearching("Mirakurun") == "Mirakurun を探しています…")
        #expect(AppStrings.reservationCancelConfirmation("番組 & ニュース") == "「番組 & ニュース」の予約を取り消しますか？")
        #expect(AppStrings.programTimeRange("10:00", "11:00") == "10:00から11:00")
        #expect(AppStrings.guideSetupHelp.contains("\n設定画面"))
    }
}
