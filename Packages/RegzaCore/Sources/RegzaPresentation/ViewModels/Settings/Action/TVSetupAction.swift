public import Foundation

/// 設定の中のテレビの登録の操作 (SettingsAction.tv で送る)
public enum TVSetupAction: Sendable {
    /// 画面を開いた。未設定なら探し始める
    case appear
    case setHost(String)
    case setUser(String)
    case setPassword(String)
    case setPIN(String)
    case setShowingManualEntry(Bool)
    case scan
    /// 未登録なら、選んだテレビにそのまま PIN を表示させる。
    /// 登録済みなら IP アドレスだけ変える (DHCP でアドレスが変わった場合など)
    /// 見つかったテレビを選ぶ (DeviceItem の host)
    case select(String)
    case startPairing
    /// PIN で登録を確定して保存する
    case confirmPairing
    case cancelPairing
    case test
    /// 画面を閉じた。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
    case close
}
