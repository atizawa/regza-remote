public import Foundation

/// 設定の中のテレビの登録の状態 (SettingsState.tv)
public struct TVSetupState: Equatable, Sendable {
    /// 入力中の接続情報 (保存するまで RemoteViewModel には入れない)
    public var host: String
    public var user: String
    public var password: String
    /// アドレスが入っている (接続テストや PIN の登録ができる)
    public var hasAddress: Bool
    /// 見つかったテレビ
    public var devices: [DeviceItem]
    public var isScanning: Bool
    public var scanMessage: String?
    /// テレビに PIN が表示されていて、入力を待っている
    public var isWaitingForPIN: Bool
    public var pin: String
    public var isPairing: Bool
    public var pairingMessage: String?
    /// PIN で登録して保存できた (画面を閉じる)
    public var hasRegistered: Bool
    /// このアプリの ID で登録済みか
    public var isRegistered: Bool
    /// ユーザー名とパスワードの入力欄を開いているか (PIN 登録に対応していない機種なら開く)
    public var isShowingManualEntry: Bool
    public var isTesting: Bool
    public var testResult: String?
    /// 一覧に出すテレビの状態
    public var status: TVSetupStatus
    /// 保存できるか (アドレスがあり、PIN の入力を待っていない)
    public var canSave: Bool
}
