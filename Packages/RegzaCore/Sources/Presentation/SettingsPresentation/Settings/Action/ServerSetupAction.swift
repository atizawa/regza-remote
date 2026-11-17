import Foundation
import PresentationCore

/// 設定の中の録画サーバーの操作 (SettingsAction.server で送る)
public enum ServerSetupAction: Sendable {
    /// アドレスをポートと合わせて入れる (`192.168.0.2` か `192.168.0.2:40772`。探して見つかったものを選んだとき)
    case setHost(ServerSetupServer, String)
    /// アドレスの欄を変える (ポートはそのまま)
    case setAddress(ServerSetupServer, String)
    /// ポートの欄を変える (アドレスはそのまま。空なら標準のポート)
    case setPort(ServerSetupServer, String)
    case scan(ServerSetupServer)
    /// Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
    case suggestStreamHost
    /// 連携をやめる。すぐにアドレスを消して反映する。EPGStation だけでは使えないので、番組表を外したら一緒に外す
    case unlink(ServerSetupServer)
}
