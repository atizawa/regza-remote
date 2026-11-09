public import Foundation

/// 設定の中の録画サーバーの操作 (SettingsAction.server で送る)
public enum ServerSetupAction: Sendable {
    case setHost(ServerSetupServer, String)
    case scan(ServerSetupServer)
    /// Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
    case suggestStreamHost
    /// 連携をやめる。すぐにアドレスを消して反映する。EPGStation だけでは使えないので、番組表を外したら一緒に外す
    case unlink(ServerSetupServer)
}
