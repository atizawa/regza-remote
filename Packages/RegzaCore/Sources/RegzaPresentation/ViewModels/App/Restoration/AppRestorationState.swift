import Foundation

/// OS の画面復元に必要な入力と選択だけを保存する。認証情報・取得結果・通信状態は含めない。
struct AppRestorationState: Codable {
    var version = 1
    var tab: AppTab
    var paths: [AppTab: [AppRoute]]
    var isShowingNowPlaying: Bool
    var settings: SettingsRestorationState?
    var search: SearchRestorationState
    var selectedDay: Date?
    var selectedBand: String?
}

struct SettingsRestorationState: Codable {
    var path: [SettingsPage]
    var host: String
    var user: String
    var isShowingManualEntry: Bool
    var guideHost: String
    var streamHost: String
}

struct SearchRestorationState: Codable {
    var text: String
    var isLiteral: Bool
    var removed: Set<GuideSearchCondition>
}
