public import Foundation

/// 設定する録画サーバー (番組表の Mirakurun・ライブ視聴の EPGStation)
public enum ServerSetupServer: String, CaseIterable, Sendable {
    case guide, stream
}
