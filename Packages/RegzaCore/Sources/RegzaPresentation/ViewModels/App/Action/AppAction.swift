public import Foundation

/// アプリ全体の操作 (AppViewModel.Action)
public enum AppAction: Sendable {
    case selectTab(AppTab)
    /// いまのタブの path に画面を積む (画面を開く)
    case push(AppRoute)
    /// いまのタブの path から 1 つ取り除く (1 つ戻る)
    case pop
    /// タブの path をまとめて変える (SwiftUI の NavigationStack が戻るボタンやスワイプで戻したとき)
    case setPath(AppTab, [AppRoute])
    case showSettings
    /// 設定を閉じる (保存は設定の画面の SettingsAction.save)
    case closeSettings
    case showNowPlaying
    case closeNowPlaying
    /// アプリで見る (ライブ視聴)
    case play(channelCode: String)
    case closePlayer
}
