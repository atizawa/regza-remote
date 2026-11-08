import Foundation

/// 放送の種類 (地デジ・BS・CS)。番組表・チャンネル・ライブ視聴で、選んで切り替える
public enum BroadcastBand: String, CaseIterable, Sendable {
    case terrestrial, bs, cs, other

    /// 「地デジ」「BS」「CS」
    public var label: String {
        switch self {
        case .terrestrial: "地デジ"
        case .bs: "BS"
        case .cs: "CS"
        case .other: "その他"
        }
    }
}
