public import Foundation

/// 番組表の検索で読み取った条件と、画面に出す名前 (GuideSearchViewModel.ConditionChip)
public struct GuideSearchConditionChip: Equatable, Sendable, Identifiable {
    public var condition: GuideSearchCondition
    /// 「明日」「18時〜」「スポーツ」
    public var label: String
    public var id: GuideSearchCondition { condition }
}
