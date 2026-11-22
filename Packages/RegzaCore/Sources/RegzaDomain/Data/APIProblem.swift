import Foundation

/// HTTP API が返すエラーの詳細 (RFC 9457 Problem Details for HTTP APIs。`application/problem+json`)。
/// 分岐には変わらない識別子の type を使い、title・detail は人が読むための説明なので分岐に使わない
public struct APIProblem: Codable, Equatable, Sendable {
    /// エラーの種類を表す URI。省いたときは about:blank (HTTP のステータスのとおりの意味)
    public var type: String
    /// 種類の短い説明
    public var title: String?
    /// HTTP のステータス
    public var status: Int?
    /// そのときの詳しい説明
    public var detail: String?
    /// 起きた場所を表す URI
    public var instance: String?

    /// 種類を書かないときの type
    public static let blankType = "about:blank"

    public init(type: String = Self.blankType, title: String? = nil, status: Int? = nil, detail: String? = nil, instance: String? = nil) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
    }

    enum CodingKeys: String, CodingKey { case type, title, status, detail, instance }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? Self.blankType
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decodeIfPresent(Int.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
    }

    /// 返事の種類が problem+json か (`application/problem+json; charset=utf-8` なども含む)
    public static func isProblem(contentType: String?) -> Bool {
        contentType?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() == "application/problem+json"
    }
}
