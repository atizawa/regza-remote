import Observation
import RegzaDomain

/// 同じテレビを使う Repository 間で共有する接続状態。APIClient の更新はテレビの設定変更と一緒に行う。
@MainActor
@Observable
public final class RegzaConnectionState {
    public private(set) var connection: ConnectionData
    public private(set) var revision = 0

    public init(connection: ConnectionData) { self.connection = connection }

    func update(_ connection: ConnectionData) {
        guard self.connection != connection else { return }
        self.connection = connection
        revision += 1
    }
}
