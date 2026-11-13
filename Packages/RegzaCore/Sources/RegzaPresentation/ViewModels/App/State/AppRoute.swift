public import Foundation

/// タブの中で開く画面 (path に積む)
public enum AppRoute: Hashable, Codable, Sendable, Identifiable {
    /// 1 チャンネルの番組表
    case channelPrograms(channelCode: String)
    /// 番組の詳細 (番組の id とチャンネルのコード)。番組とチャンネルは UseCase から引く
    case programDetail(programID: Int, channelCode: String)
    /// 番組表の検索
    case search

    /// 画面を見分ける文字列 (同じ画面なら同じ。Compose の back stack の key などに使う)
    public var id: String {
        switch self {
        case .channelPrograms(let channelCode): "channelPrograms/\(channelCode)"
        case .programDetail(let programID, let channelCode): "programDetail/\(channelCode)/\(programID)"
        case .search: "search"
        }
    }
}
