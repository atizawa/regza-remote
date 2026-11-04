import Foundation

/// 録画予約 (`GET /v2/remote/pvr/reserves/list`)。
///
/// 連ドラ予約は次の回が番組表に載ると `start_time` と `title` がその回に更新される。
/// 次の回がまだ見つかっていない間は、最後に録画した回の時刻のまま残る。
public struct RegzaReservation: Decodable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// チャンネル一覧の `RegzaChannel.code` と同じ
    public var channelCode: String
    /// 予約した番組のテレビの番組 ID。連ドラ予約で次の回が未定のときは event_id が `ffff`
    public var epgContentID: String
    public var start: Date
    /// 秒
    public var duration: Int
    /// `none` / `daily` / `weekly` / `mtof` (月〜金) / `mtos` (月〜土) など
    public var repeatRule: String
    /// 連ドラ予約か
    public var isSeries: Bool

    public var end: Date { start.addingTimeInterval(TimeInterval(duration)) }

    /// この予約がその番組 (テレビの番組 ID) のものか。16 進の大文字・小文字はテレビと Mirakurun で違うことがあるので区別しない
    public func isReservation(of epgContentID: String) -> Bool {
        !epgContentID.isEmpty && self.epgContentID.caseInsensitiveCompare(epgContentID) == .orderedSame
    }

    /// 次に録画する予定があるか (録画中も含む)
    public func isScheduled(now: Date = Date()) -> Bool { end > now }

    public var repeatLabel: String? {
        switch repeatRule {
        case "daily": "毎日"
        case "weekly": "毎週"
        case "mtof": "月〜金"
        case "mtos": "月〜土"
        case "", "none": nil
        default: "繰り返し"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "rsv_id"
        case title
        case channelCode = "channel"
        case epgContentID = "epg_content_id"
        case start = "start_time"
        case duration
        case repeatRule = "repeat"
        case isSeries = "series_rec"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = RegzaNowPlaying.cleanTitle(try container.decodeIfPresent(String.self, forKey: .title) ?? "")
        channelCode = try container.decodeIfPresent(String.self, forKey: .channelCode) ?? ""
        epgContentID = try container.decodeIfPresent(String.self, forKey: .epgContentID) ?? ""
        start = Date(timeIntervalSince1970: TimeInterval(try container.decodeIfPresent(Int.self, forKey: .start) ?? 0))
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        repeatRule = try container.decodeIfPresent(String.self, forKey: .repeatRule) ?? ""
        isSeries = try container.decodeIfPresent(String.self, forKey: .isSeries) == "true"
    }
}

struct RegzaReservationList: Decodable {
    var status: Int
    var reservations: [RegzaReservation]?

    enum CodingKeys: String, CodingKey {
        case status
        case reservations = "rsv_list"
    }
}
