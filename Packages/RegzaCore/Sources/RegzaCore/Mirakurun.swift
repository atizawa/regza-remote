import Foundation

/// Mirakurun の番組 (`GET /api/programs`)。
public struct MirakurunProgram: Decodable, Hashable, Sendable, Identifiable {
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
    }

    /// テレビのチャンネル一覧の `RegzaChannel.code` と同じ形式
    public var channelCode: String { Mirakurun.channelCode(networkId: networkId, serviceId: serviceId) }

    /// テレビの番組 ID (`epg_content_id`)。録画予約に使う
    public var epgContentID: String {
        Mirakurun.epgContentID(networkId: networkId, serviceId: serviceId, eventId: eventId)
    }

    public func isOnAir(at date: Date = Date()) -> Bool { start <= date && date < end }

    /// 最初のジャンルの名前
    public var genreName: String? { genres.first.flatMap(Mirakurun.genreName) }

    enum CodingKeys: String, CodingKey {
        case id, networkId, serviceId, eventId, startAt, duration, name, description, extended, genres
    }

    struct Genre: Decodable {
        var lv1: Int
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        networkId = try container.decode(Int.self, forKey: .networkId)
        serviceId = try container.decode(Int.self, forKey: .serviceId)
        eventId = try container.decodeIfPresent(Int.self, forKey: .eventId) ?? id % 100_000
        // ミリ秒
        let startAt = try container.decode(Double.self, forKey: .startAt)
        let duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        start = Date(timeIntervalSince1970: startAt / 1000)
        end = Date(timeIntervalSince1970: (startAt + duration) / 1000)
        name = RegzaNowPlaying.cleanTitle(try container.decodeIfPresent(String.self, forKey: .name) ?? "")
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        let extended = try container.decodeIfPresent([String: String].self, forKey: .extended) ?? [:]
        // JSON のキーの順番は残らないので、よく出る見出しを先に並べる
        let order = ["番組内容", "出演者"]
        self.extended = extended
            .map { Extended(title: $0.key, text: $0.value) }
            .sorted { lhs, rhs in
                let left = order.firstIndex(of: lhs.title) ?? order.count
                let right = order.firstIndex(of: rhs.title) ?? order.count
                return left != right ? left < right : lhs.title < rhs.title
            }
        genres = (try container.decodeIfPresent([Genre].self, forKey: .genres) ?? []).map(\.lv1)
    }
}

/// 録画サーバー Mirakurun から番組表を読む。認証は不要。
///
/// テレビの v2 API は番組名を返さないので、放送中の番組名と番組表はこちらから取る。
/// テレビと Mirakurun は同じ放送波の ID (network_id / service_id / event_id) を使っているので、変換して照らし合わせられる。
public final class Mirakurun: Sendable {
    public static let defaultPort = 40772

    /// `192.168.0.2` か `192.168.0.2:40772`
    public let host: String
    private let timeout: TimeInterval
    private let transport: any HTTPTransport

    public init(host: String, timeout: TimeInterval = 10, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
        self.transport = transport
    }

    /// 1 番組。テレビの `epg_content_id` から `programID(epgContentID:)` で求めた ID を渡す
    public func program(id: Int) async throws -> MirakurunProgram {
        try JSONDecoder().decode(MirakurunProgram.self, from: try await get("/api/programs/\(id)"))
    }

    /// 1 チャンネルの番組 (8 日分ほど)。時刻順
    public func programs(channelCode: String) async throws -> [MirakurunProgram] {
        guard let (networkId, serviceId) = Self.ids(channelCode: channelCode) else { return [] }
        let data = try await get("/api/programs", query: "networkId=\(networkId)&serviceId=\(serviceId)")
        return try JSONDecoder().decode([MirakurunProgram].self, from: data).sorted { $0.start < $1.start }
    }

    /// 全チャンネルの番組。数 MB になるので、必要なときだけ呼ぶ
    public func allPrograms() async throws -> [MirakurunProgram] {
        try JSONDecoder().decode([MirakurunProgram].self, from: try await get("/api/programs"))
    }

    /// Mirakurun が応答するか
    public func isAvailable() async -> Bool {
        guard let data = try? await get("/api/version"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["current"] != nil
    }

    private func get(_ path: String, query: String? = nil) async throws -> Data {
        guard !host.isEmpty else { throw RegzaError.notConfigured }
        let authority = host.contains(":") ? host : "\(host):\(Self.defaultPort)"
        guard let url = URL(string: "http://\(authority)\(path)" + (query.map { "?\($0)" } ?? "")) else {
            throw RegzaError.invalidHost
        }
        let response = try await transport.send(HTTPRequest(url: url, timeout: timeout))
        guard (200..<300).contains(response.statusCode) else { throw RegzaError.httpStatus(response.statusCode) }
        return response.body
    }

    // MARK: - テレビの ID との変換

    /// `JP-G7fe00400` (network_id 0x7fe0, service_id 0x0400)
    public static func channelCode(networkId: Int, serviceId: Int) -> String {
        "JP-G" + hex4(networkId) + hex4(serviceId)
    }

    static func ids(channelCode code: String) -> (networkId: Int, serviceId: Int)? {
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

    /// ARIB STD-B10 のジャンル大分類
    static let genreNames = [
        "ニュース", "スポーツ", "情報", "ドラマ", "音楽", "バラエティ",
        "映画", "アニメ", "ドキュメンタリー", "劇場・公演", "趣味・教育", "福祉",
    ]

    static func genreName(_ level1: Int) -> String? {
        genreNames.indices.contains(level1) ? genreNames[level1] : nil
    }

    // MARK: - 探す

    /// 同じネットワークで Mirakurun が動いているアドレスを探す
    public static func find(timeout: TimeInterval = 1.5) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask { await Mirakurun(host: host, timeout: timeout).isAvailable() ? host : nil }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask { await Mirakurun(host: next, timeout: timeout).isAvailable() ? next : nil }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }
}
