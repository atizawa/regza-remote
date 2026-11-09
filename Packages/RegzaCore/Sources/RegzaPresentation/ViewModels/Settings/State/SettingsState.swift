public import Foundation

/// 設定の画面の状態 (SettingsViewModel.State)
public struct SettingsState: Equatable, Sendable {
    /// 開いている設定の中の画面 (最後が手前の画面)。設定の最初の画面なら空
    public var path: [SettingsPage]
    /// 閉じられる (登録済みのテレビがある)
    public var canClose: Bool
    /// 保存できる (テレビのアドレスがあって PIN の入力を待っておらず、録画サーバーのポートが正しい)
    public var canSave: Bool
    /// テレビの登録
    public var tv: TVSetupState
    /// 録画サーバー (番組表・ライブ視聴)
    public var servers: ServerSetupState
}
