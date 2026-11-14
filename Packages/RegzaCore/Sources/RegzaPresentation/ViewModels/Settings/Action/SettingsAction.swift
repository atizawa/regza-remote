public import Foundation

/// 設定の画面からの操作 (SettingsViewModel.Action)
public enum SettingsAction: Sendable {
    /// 選択時に保存し、アプリ全体へ即時反映する。
    case setAppearance(AppAppearance)
    /// 設定の中の画面をまとめて変える (iOS の戻るボタンやスワイプで戻ったとき)
    case setPath([SettingsPage])
    /// 設定の中の画面を開く
    case openPage(SettingsPage)
    /// 設定の中で 1 つ戻る
    case back
    /// 保存して閉じる
    case save
    /// 保存せずに閉じる
    case close
    /// テレビの登録の操作
    case tv(TVSetupAction)
    /// 録画サーバー (番組表・ライブ視聴) の操作
    case server(ServerSetupAction)
}
