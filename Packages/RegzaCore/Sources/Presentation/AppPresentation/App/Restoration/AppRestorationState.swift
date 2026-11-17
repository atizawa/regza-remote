import Foundation
public import GuidePresentation
public import PresentationCore
public import SettingsPresentation

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
