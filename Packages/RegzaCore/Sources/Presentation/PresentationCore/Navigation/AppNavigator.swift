/// 機能の画面が、アプリ全体の画面の移り変わり (タブの戻る道・いま映っているものの画面・アプリで見る・設定) を頼む窓口。
/// アプリ全体の ViewModel が実装する。機能はアプリ全体のモジュールを読み込まずに、この窓口だけを使う。
/// 頼むだけの窓口にし、戻る道やシートを出しているかなどの状態は置かない (表示は組み立てが、アプリ全体の state を読んで決める)。
/// Android の AppNavigator も同じ形にそろえる
@MainActor
public protocol AppNavigator: AnyObject {
    /// いまのタブに画面を積む
    func push(_ route: AppRoute)
    /// アプリで見る (ライブ視聴)
    func play(channelCode: String)
    /// アプリで見るのをやめる
    func closePlayer()
    /// いま映っているものの画面を出す
    func showNowPlaying()
    func closeNowPlaying()
    /// 設定の画面を開く
    func showSettings()
}
