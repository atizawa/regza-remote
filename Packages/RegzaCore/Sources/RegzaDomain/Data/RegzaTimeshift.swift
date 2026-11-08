import Foundation

/// タイムシフトマシンの設定 (`GET /v2/remote/settings/timeshift`)。
///
/// `active_time_list` は曜日ごとの録画する時間帯で、`00f80001` のような 16 進の値の下位 24 ビットが 0〜23 時を表す。
/// 例: テレビの設定が「平日 19 時〜翌 1 時」なら平日は `00f80001` (19〜23 時と、その日の 0 時台)。
/// 翌日の 0 時台は翌日の値の 0 ビット目に入る
public struct RegzaTimeshiftSettings: Decodable, Sendable, Equatable {
    public var isEnabled: Bool
    /// 録画している局 (`RegzaChannel.code`)
    public var targetChannels: [String]
    /// 曜日 (`Calendar` の weekday、日曜 = 1) ごとの録画する時間のビット
    var activeHours: [Int: UInt32]

    enum CodingKeys: String, CodingKey {
        case isEnabled = "timeshift_enabled"
        case targetChannels = "target_channel"
        case activeTimes = "active_time_list"
    }

    struct ActiveTime: Decodable {
        var activeTime: String
        var dayOfWeek: String

        enum CodingKeys: String, CodingKey {
            case activeTime = "active_time"
            case dayOfWeek = "day_of_week"
        }
    }

    private static let weekdays = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try container.decodeIfPresent(String.self, forKey: .isEnabled)) == "true"
        targetChannels = try container.decodeIfPresent([String].self, forKey: .targetChannels) ?? []
        var hours: [Int: UInt32] = [:]
        for item in try container.decodeIfPresent([ActiveTime].self, forKey: .activeTimes) ?? [] {
            if let weekday = Self.weekdays[item.dayOfWeek], let bits = UInt32(item.activeTime, radix: 16) {
                hours[weekday] = bits
            }
        }
        activeHours = hours
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }

    /// その時刻にタイムシフトマシンが録画している時間帯か
    func isActive(at date: Date) -> Bool {
        let calendar = Self.calendar
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        guard let bits = activeHours[weekday] else { return false }
        return bits & (1 << UInt32(hour)) != 0
    }

    /// その局の、`start` に始まった番組を最初から見られるか (始まりから今まで、ずっと録画している時間帯か)。
    /// 録画していない番組で「始めにジャンプ」を押すと、テレビにエラーが出る
    public func canStartOver(channelCode: String, programStart start: Date, now: Date = Date()) -> Bool {
        guard isEnabled, targetChannels.contains(channelCode), start <= now else { return false }
        var time = start
        while time < now {
            guard isActive(at: time) else { return false }
            // 次の正時へ
            let calendar = Self.calendar
            guard let next = calendar.nextDate(after: time, matching: DateComponents(minute: 0, second: 0),
                                               matchingPolicy: .nextTime) else { return false }
            time = next
        }
        return isActive(at: now)
    }
}
