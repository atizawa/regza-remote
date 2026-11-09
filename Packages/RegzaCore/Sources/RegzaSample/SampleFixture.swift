import Foundation
import RegzaPresentation

/// 見本の返事を、テストごとに差し替える (Shopify の Reflex の fixture と同じ考え方)。
/// 振る舞いのテストが、「テレビにつながらない」「チャンネル一覧が空」のような場面を作るために使う。
/// CLI (regza) と Android 側の相手 (regza-android) に、起動するときに --fixture <JSON のファイル> で渡す
///
///     {
///       "responses": { "/v2/remote/settings/channel_list": { "status": 200, "body": { "status": 0, "channel_list": [] } } },
///       "unreachable": ["192.0.2.10"]
///     }
public struct SampleFixture: Decodable, Sendable {
    /// 宛先 (URL の path) ごとに差し替える返事
    public var responses: [String: Response] = [:]
    /// つながらないアドレス (そこへの通信は、本物と同じく「接続できません」で失敗する)
    public var unreachable: [String] = []

    public struct Response: Decodable, Sendable {
        public var status: Int = 200
        /// 返事の中身 (JSON)
        public var body: JSONValue = .object([:])

        enum CodingKeys: String, CodingKey { case status, body }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 200
            body = try container.decodeIfPresent(JSONValue.self, forKey: .body) ?? .object([:])
        }
    }

    enum CodingKeys: String, CodingKey { case responses, unreachable }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        responses = try container.decodeIfPresent([String: Response].self, forKey: .responses) ?? [:]
        unreachable = try container.decodeIfPresent([String].self, forKey: .unreachable) ?? []
    }

    /// JSON から読む
    public init(json: String) throws {
        self = try JSONDecoder().decode(SampleFixture.self, from: Data(json.utf8))
    }
}
