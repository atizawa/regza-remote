import Foundation

/// HTTP API が返すエラーの詳細 (RFC 9457 Problem Details for HTTP APIs。`application/problem+json`)。
/// 分岐には変わらない識別子の type か、API が決めた code (拡張メンバー) を使い、
/// title・detail は人が読むための説明なので分岐に使わない
public struct APIProblem: Codable, Equatable, Sendable {
    /// エラーの種類を表す URI。省いたときは about:blank (HTTP のステータスのとおりの意味)
    public var type: String
    /// 種類の短い説明
    public var title: String?
    /// HTTP のステータス。本文の status は目安 (RFC 9457) なので、通信が返事のステータスにそろえる
    public var status: Int?
    /// そのときの詳しい説明
    public var detail: String?
    /// 起きた場所を表す URI
    public var instance: String?
    /// API が決めた、エラーを見分ける code (RFC 9457 の拡張メンバー)。数で返す API もあるので、文字にして持つ。
    /// 名前は API ごとに違うので、codeMembers の名前のうち最初に見つかったものを読む
    public var code: String?

    /// API が決めた code を返す拡張メンバーの名前。API が別の名前で返すときは、ここに足す
    public static let codeMembers = ["code"]

    /// 種類を書かないときの type
    public static let blankType = "about:blank"

    /// 種類 (type) か API が決めた code で、エラーを見分けられるか。どちらもなければ HTTP のステータスのとおりの意味
    public var isIdentified: Bool { type != Self.blankType || code != nil }

    public init(
        type: String = Self.blankType, title: String? = nil, status: Int? = nil, detail: String? = nil, instance: String? = nil,
        code: String? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
        self.code = code
    }

    enum CodingKeys: String, CodingKey { case type, title, status, detail, instance }

    /// 拡張メンバーの名前
    struct MemberKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? Self.blankType
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decodeIfPresent(Int.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
        let members = try decoder.container(keyedBy: MemberKey.self)
        code = Self.codeMembers.lazy.compactMap { Self.code(in: members, forKey: MemberKey(stringValue: $0)) }.first
    }

    /// 拡張メンバーの code を文字で読む。数も文字にする。空のときと、文字でも数でもないときは、code がないものとする
    static func code(in members: KeyedDecodingContainer<MemberKey>, forKey key: MemberKey) -> String? {
        let text =
            (try? members.decodeIfPresent(String.self, forKey: key))
            ?? (try? members.decodeIfPresent(Int.self, forKey: key)).map(String.init)
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encodeIfPresent(instance, forKey: .instance)
        if let name = Self.codeMembers.first {
            var members = encoder.container(keyedBy: MemberKey.self)
            try members.encodeIfPresent(code, forKey: MemberKey(stringValue: name))
        }
    }

    /// 返事の種類が problem+json か (`application/problem+json; charset=utf-8` なども含む)
    public static func isProblem(contentType: String?) -> Bool {
        contentType?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() == "application/problem+json"
    }
}
