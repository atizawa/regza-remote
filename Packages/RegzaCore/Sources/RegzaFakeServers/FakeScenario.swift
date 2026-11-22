#if !REGZA_FAKES_DISABLED
import Foundation
import RegzaPresentation

/// 偽物をどの場面から始めるか。プレビュー・振る舞いのテスト・CLI が名前で選び、同じ場面を作る。
/// 一つのテストでしか使わない差し替えは、名前の場面に JSON で足す (宛先のパスごとの返事と、つながらないアドレス)
///
///     {
///       "base": "standard",
///       "responses": { "/v2/remote/settings/channel_list": { "status": 200, "body": { "status": 0, "channel_list": [] } } },
///       "unreachable": ["192.0.2.10"]
///     }
public struct FakeScenario: Sendable {
    public enum Name: String, CaseIterable, Codable, Sendable {
        /// テレビ・Mirakurun・EPGStation が登録済みで、放送を見ている
        case standard
        /// 録画を再生している
        case recordedPlaying
        /// Mirakurun が登録されていない
        case noGuideServer
        /// テレビが登録されていない (最初の起動)
        case notRegistered
        /// テレビにつながらない
        case tvUnreachable
        /// テレビにチャンネルが登録されていない
        case emptyChannels
        /// Mirakurun につながらない
        case guideUnreachable
    }

    public enum Playing: Sendable {
        case broadcast
        case recorded
        case standby
    }

    public struct Response: Decodable, Sendable {
        public var status: Int = 200
        /// 返事の中身 (JSON)
        public var body: JSONValue = .object([:])

        enum CodingKeys: String, CodingKey { case status, body }

        public init(status: Int = 200, body: JSONValue = .object([:])) {
            self.status = status
            self.body = body
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 200
            body = try container.decodeIfPresent(JSONValue.self, forKey: .body) ?? .object([:])
        }
    }

    /// アプリに登録済みのもの
    public var registersTV = true
    public var registersGuide = true
    public var registersStream = true
    /// テレビが映しているもの
    public var playing = Playing.broadcast
    public var tvHasChannels = true
    /// 録画予約が 1 件ある
    public var hasReservation = true
    /// つながらないアドレス (そこへの通信は、本物と同じく「つながらない」失敗になる)
    public var unreachable: [String] = []
    /// 宛先 (URL の path) ごとに差し替える返事
    public var responses: [String: Response] = [:]

    public static let standard = FakeScenario()

    public init() {}

    public init(_ name: Name) {
        switch name {
        case .standard: break
        case .recordedPlaying: playing = .recorded
        case .noGuideServer: registersGuide = false
        case .notRegistered: (registersTV, registersGuide, registersStream) = (false, false, false)
        case .tvUnreachable: unreachable = [FakeServers.Host.tv]
        case .emptyChannels: tvHasChannels = false
        case .guideUnreachable: unreachable = [FakeServers.Host.guide]
        }
    }

    /// JSON から読む (`base` を省くと standard)
    public init(json: String) throws {
        let overrides = try JSONDecoder().decode(Overrides.self, from: Data(json.utf8))
        self.init(overrides.base ?? .standard)
        unreachable += overrides.unreachable ?? []
        responses.merge(overrides.responses ?? [:]) { _, new in new }
    }

    private struct Overrides: Decodable {
        var base: Name?
        var responses: [String: Response]?
        var unreachable: [String]?
    }
}
#endif
