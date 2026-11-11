import Foundation

/// Mirakurun の番組 (`GET /api/programs`)。
public struct ProgramData: Decodable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var networkId: Int
    public var serviceId: Int
    public var eventId: Int
    public var start: Date
    public var end: Date
    public var name: String
    public var description: String
    /// `番組内容` `出演者` など。番組内容を先にした配列
    public var extended: [Extended]
    /// ARIB の大分類 (0: ニュース/報道 〜 11: 福祉)
    public var genres: [Int]

    public struct Extended: Hashable, Sendable {
        public var title: String
        public var text: String

        public init(title: String, text: String) {
            self.title = title
            self.text = text
        }
    }

    public init(
        id: Int, networkId: Int, serviceId: Int, eventId: Int, start: Date, end: Date,
        name: String = "", description: String = "", extended: [Extended] = [], genres: [Int] = []
    ) {
        self.id = id
        self.networkId = networkId
        self.serviceId = serviceId
        self.eventId = eventId
        self.start = start
        self.end = end
        self.name = NowPlayingData.cleanTitle(name)
        self.description = description
        let order = ["番組内容", "出演者"]
        self.extended = extended.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.title) ?? order.count
            let right = order.firstIndex(of: rhs.title) ?? order.count
            return left != right ? left < right : lhs.title < rhs.title
        }
        self.genres = genres
    }

    /// テレビのチャンネル一覧の `ChannelData.code` と同じ形式
    public var channelCode: String { BroadcastID.channelCode(networkId: networkId, serviceId: serviceId) }

    /// テレビの番組 ID (`epg_content_id`)。録画予約に使う
    public var epgContentID: String {
        BroadcastID.epgContentID(networkId: networkId, serviceId: serviceId, eventId: eventId)
    }

    public func isOnAir(at date: Date = Date()) -> Bool { start <= date && date < end }

    /// 最初のジャンルの名前
    public var genreName: String? { genres.first.flatMap(ProgramGenre.name) }

    enum CodingKeys: String, CodingKey {
        case id, networkId, serviceId, eventId, startAt, duration, name, description, extended, genres
    }

    struct Genre: Decodable {
        var lv1: Int
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Int.self, forKey: .id)
        // ミリ秒
        let startAt = try container.decode(Double.self, forKey: .startAt)
        let duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        let extended = try container.decodeIfPresent([String: String].self, forKey: .extended) ?? [:]
        self.init(
            id: id, networkId: try container.decode(Int.self, forKey: .networkId),
            serviceId: try container.decode(Int.self, forKey: .serviceId),
            eventId: try container.decodeIfPresent(Int.self, forKey: .eventId) ?? id % 100_000,
            start: Date(timeIntervalSince1970: startAt / 1000), end: Date(timeIntervalSince1970: (startAt + duration) / 1000),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "",
            description: try container.decodeIfPresent(String.self, forKey: .description) ?? "",
            extended: extended.map { Extended(title: $0.key, text: $0.value) },
            genres: (try container.decodeIfPresent([Genre].self, forKey: .genres) ?? []).map(\.lv1)
        )
    }
}
