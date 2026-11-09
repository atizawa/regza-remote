public import Foundation

/// 番組表の検索の画面からの操作 (GuideSearchViewModel.Action)
public enum GuideSearchAction: Sendable {
    case setText(String)
    /// 読み取った条件から 1 つ外す
    case removeCondition(GuideSearchCondition)
    /// 条件を読み取らず、打った言葉そのままで探す
    case searchLiterally
}
