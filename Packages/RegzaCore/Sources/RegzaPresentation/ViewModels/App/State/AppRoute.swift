public import Foundation

/// タブの中で開く画面 (path に積む)
public enum AppRoute: Hashable, Sendable {
    /// 1 チャンネルの番組表
    case channelPrograms(channelCode: String)
    /// 番組の詳細 (番組の id とチャンネルのコード)。番組とチャンネルは UseCase から引く
    case programDetail(programID: Int, channelCode: String)
    /// 番組表の検索
    case search
}
