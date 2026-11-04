import Foundation

/// 番組表の 1 日。日本の番組表と同じく朝 4 時に始まり、深夜番組は前の日の続きとして 24〜27 時と書く
/// (番組表の画面と番組の検索で使う)
public enum BroadcastDay {
    /// 1 日の始まり (朝 4 時)
    public static let startHour = 4

    /// その時刻が入る 1 日の始まり (その日か前の日の朝 4 時)
    public static func start(of date: Date, calendar: Calendar = .current) -> Date {
        let shifted = date.addingTimeInterval(-TimeInterval(startHour * 3600))
        return calendar.startOfDay(for: shifted).addingTimeInterval(TimeInterval(startHour * 3600))
    }

    /// 番組表での時刻 (4〜27 時)。朝 4 時より前は前の日の続きとして 24 時を足す
    public static func hour(of date: Date, calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        return hour < startHour ? hour + 24 : hour
    }
}
