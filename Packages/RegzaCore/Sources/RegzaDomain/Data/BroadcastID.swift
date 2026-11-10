import Foundation

/// 放送の ID の変換。テレビ (`JP-G…` のチャンネル、`JP-0000…` の番組) と Mirakurun・EPGStation は
/// 同じ放送波の ID (network_id / service_id / event_id) を使っているので、変換して照らし合わせられる
public enum BroadcastID {
    /// `JP-G7fe00400` (network_id 0x7fe0, service_id 0x0400)
    public static func channelCode(networkId: Int, serviceId: Int) -> String {
        "JP-G" + hex4(networkId) + hex4(serviceId)
    }

    public static func ids(channelCode code: String) -> (networkId: Int, serviceId: Int)? {
        guard code.hasPrefix("JP-G"), code.count == 12 else { return nil }
        let digits = code.dropFirst(4)
        guard let networkId = Int(digits.prefix(4), radix: 16), let serviceId = Int(digits.suffix(4), radix: 16) else {
            return nil
        }
        return (networkId, serviceId)
    }

    public static func epgContentID(networkId: Int, serviceId: Int, eventId: Int) -> String {
        "JP-0000" + hex4(networkId) + hex4(serviceId) + hex4(eventId)
    }

    /// テレビの `epg_content_id` (`JP-0000` + network_id + service_id + event_id の 16 進) を Mirakurun の番組 ID にする
    public static func programID(epgContentID: String) -> Int? {
        guard epgContentID.hasPrefix("JP-") else { return nil }
        let digits = epgContentID.dropFirst(3)
        guard digits.count == 16,
            let networkId = Int(digits.dropFirst(4).prefix(4), radix: 16),
            let serviceId = Int(digits.dropFirst(8).prefix(4), radix: 16),
            let eventId = Int(digits.suffix(4), radix: 16),
            eventId != 0xFFFF
        else { return nil }
        return networkId * 10_000_000_000 + serviceId * 100_000 + eventId
    }

    private static func hex4(_ value: Int) -> String {
        let hex = String(value, radix: 16)
        return String(repeating: "0", count: max(0, 4 - hex.count)) + hex
    }
}

/// 番組のジャンル
public enum ProgramGenre {
    /// ARIB STD-B10 のジャンル大分類
    public static let names = [
        "ニュース", "スポーツ", "情報", "ドラマ", "音楽", "バラエティ",
        "映画", "アニメ", "ドキュメンタリー", "劇場・公演", "趣味・教育", "福祉",
    ]

    public static func name(_ level1: Int) -> String? {
        names.indices.contains(level1) ? names[level1] : nil
    }
}
