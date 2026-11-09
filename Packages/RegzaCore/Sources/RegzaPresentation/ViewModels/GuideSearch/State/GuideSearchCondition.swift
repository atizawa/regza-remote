public import Foundation

/// 番組表の検索で読み取った条件の種類 (GuideSearchViewModel.Condition)
public enum GuideSearchCondition: Hashable, Sendable {
    case day, hours, genre(Int)
}
