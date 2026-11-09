public import Foundation

/// 番組表の検索の画面の状態 (GuideSearchViewModel.State)
public struct GuideSearchState: Equatable, Sendable {
    public var text: String
    /// 何も打っていない
    public var isBlank: Bool
    /// 読み取った条件 (外したものを除く)
    public var conditions: [GuideSearchConditionChip]
    /// 条件を読み取らず、打った言葉そのままで探しているか (「夜のニュース」という番組名を探すときなど)
    public var isLiteral: Bool
    /// 索引を作っている途中か (その間は結果が空でも「見つかりません」と出さない)
    public var isIndexing: Bool
    /// 見つかった番組 (テレビに登録されていない局の番組は出さない)
    public var results: [SearchResultItem]
}
