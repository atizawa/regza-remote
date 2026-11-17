import Foundation

/// 機能の画面が、アプリ全体の画面の移り変わり (タブの戻る道・いま映っているものの画面・アプリで見る) を頼む窓口。
/// アプリ全体の ViewModel が実装する。機能はアプリ全体のモジュールを読み込まずに、この窓口だけを使う
@MainActor
public protocol AppNavigator: AnyObject {
    /// タブの戻る道 (積んだ画面の並び)
    func routes(of tab: AppTab) -> [AppRoute]
    /// タブの戻る道をまとめて変える (戻るボタンやスワイプで戻したとき)
    func setRoutes(_ routes: [AppRoute], of tab: AppTab)
    /// いまのタブに画面を積む
    func push(_ route: AppRoute)
    /// アプリで見る (ライブ視聴)
    func play(channelCode: String)
    /// アプリで見ている
    var isPlaying: Bool { get }
    /// アプリで見るのをやめる
    func closePlayer()
    /// いま映っているものの画面を出している
    var isShowingNowPlaying: Bool { get }
    func showNowPlaying()
    func closeNowPlaying()
    /// 設定の画面を開く
    func showSettings()
}
