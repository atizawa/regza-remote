public import Foundation

/// 設定の中の録画サーバーの状態 (SettingsState.servers)
public struct ServerSetupState: Equatable, Sendable {
    public var guide: ServerSetupServerState
    public var stream: ServerSetupServerState
    /// Mirakurun のアドレスが入っているか (保存前の入力も含む)。EPGStation は Mirakurun から放送を受け取るので、
    /// Mirakurun を入れてから設定できるようにする
    public var hasGuideDraft: Bool
    /// 入力したポートが正しいか
    public var isValid: Bool

    public subscript(server: ServerSetupServer) -> ServerSetupServerState { server == .guide ? guide : stream }
}
