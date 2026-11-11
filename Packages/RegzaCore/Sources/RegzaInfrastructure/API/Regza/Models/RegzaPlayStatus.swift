import Foundation
import RegzaDomain

/// レグザAppsコネクト v2 API `GET /v2/remote/play/status` のレスポンス。
/// 機種によっては、放送中の番組名 (`title`) が空で返る。
public struct RegzaPlayStatus: Decodable, Equatable, Sendable {
    public var status: Int
    /// `broadcast` / `recorded` / `external` (HDMI) / `other` (待機など)
    public var contentType: String?
    public var currentProgram: Program?
    public var nextProgram: Program?
    public var recordedProgram: Program?
    public var playingAction: PlayingAction?

    enum CodingKeys: String, CodingKey {
        case status
        case contentType = "content_type"
        case currentProgram = "epg_info_current"
        case nextProgram = "epg_info_next"
        case recordedProgram = "recorded_prg_info"
        case playingAction = "playing_action_info"
    }

    public struct Program: Decodable, Equatable, Sendable {
        public var channel: String?
        public var channelName: String?
        /// `JP-0000` + network_id + service_id + event_id (16 進)
        public var epgContentID: String?
        public var title: String?
        public var description: String?
        /// Unix 秒
        public var startTime: Int?
        /// 秒
        public var duration: Int?
        /// ARIB のジャンル (`00a8` のような 4 桁の 16 進。3 桁目が大分類)
        public var genre: [String]?
        /// 3 桁のチャンネル番号 (地デジ 041、BS 181 など)
        public var channelNumber: Int?
        /// リモコンの番号ボタンの番号 (地デジの 4 など)
        public var remoteNumber: Int?

        enum CodingKeys: String, CodingKey {
            case channel, title, description, duration, genre
            case channelNumber = "channel_number"
            case remoteNumber = "rcu_channel_number"
            case channelName = "channel_name"
            case epgContentID = "epg_content_id"
            case startTime = "start_time"
        }
    }

    public struct PlayingAction: Decodable, Equatable, Sendable {
        /// 秒
        public var position: Int?
        /// 秒
        public var totalTime: Int?
        /// `play` / `pause` など
        public var playState: String?
        public var chapterName: String?

        enum CodingKeys: String, CodingKey {
            case position
            case totalTime = "total_time"
            case playState = "play_state"
            case chapterName = "chapter_name"
        }
    }
}
