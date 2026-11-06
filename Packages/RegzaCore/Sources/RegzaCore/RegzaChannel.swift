import Foundation

/// テレビに登録されているチャンネル (`GET /v2/remote/settings/channel_list`)。
public struct RegzaChannel: Decodable, Hashable, Sendable, Identifiable {
    public enum Band: String, CaseIterable, Sendable {
        case terrestrial, bs, cs, other

        public var label: String {
            switch self {
            case .terrestrial: "地デジ"
            case .bs: "BS"
            case .cs: "CS"
            case .other: "その他"
            }
        }
    }

    /// 選局に使う ID (例: `JP-G7fe00400`)
    public var code: String
    /// 3 桁のチャンネル番号 (例: 地デジ 011、BS 181)
    public var number: Int
    /// リモコンのワンタッチ選局ボタンの番号。割り当てがなければ 0
    public var remoteNumber: Int
    public var name: String
    /// `DUV_011-1` (地デジ) / `DBS_181` (BS) / `DCS_055` (CS)
    var exChannelNumber: String
    /// `SHOW_REPRESENT` は同じ放送局のサブチャンネルのうち代表のもの
    var showSetting: String

    public var id: String { code }

    public var band: Band {
        switch exChannelNumber.prefix(3) {
        case "DUV": .terrestrial
        case "DBS": .bs
        case "DCS": .cs
        default: .other
        }
    }

    /// 放送局の代表チャンネルか (地デジ・BS のサブチャンネルでないもの)
    public var isRepresentative: Bool { showSetting == "SHOW_REPRESENT" }

    public var formattedNumber: String { String(format: "%03d", number) }

    enum CodingKeys: String, CodingKey {
        case code = "channel"
        case number = "channel_number"
        case remoteNumber = "rcu_channel_number"
        case name
        case exChannelNumber = "ex_channel_number"
        case showSetting = "show_setting"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 0
        remoteNumber = try container.decodeIfPresent(Int.self, forKey: .remoteNumber) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        exChannelNumber = try container.decodeIfPresent(String.self, forKey: .exChannelNumber) ?? ""
        showSetting = try container.decodeIfPresent(String.self, forKey: .showSetting) ?? ""
    }
}

struct RegzaChannelList: Decodable {
    var status: Int
    var channels: [RegzaChannel]?

    enum CodingKeys: String, CodingKey {
        case status
        case channels = "channel_list"
    }
}

struct RegzaResult: Decodable {
    var status: Int
}
