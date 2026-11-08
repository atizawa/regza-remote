import Foundation
import RegzaDomain

/// `/remote/status.htm` のレスポンス。
/// `key=value` が改行区切りで返る。録画再生中以外は各値が 0 か空になる。
public struct RegzaStatus: Equatable, Sendable {
    public var action: Int = 0
    public var titleNumber: Int = 0
    public var titleName: String = ""
    public var totalTime: Int = 0
    public var channelCode: String = ""
    public var channelName: String = ""
    public var recordedAt: String = ""
    public var genre: String = ""
    public var titleTime: Int = 0
    public var chapterNumber: Int = 0
    public var chapterTime: Int = 0
    public var chapterName: String = ""

    public init() {}

    public init(text: String) {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            values[key] = value == "null" ? "" : value
        }
        action = Int(values["action"] ?? "") ?? 0
        titleNumber = Int(values["title_no"] ?? "") ?? 0
        titleName = values["title_name"] ?? ""
        totalTime = Int(values["total_time"] ?? "") ?? 0
        channelCode = values["ch_code"] ?? ""
        channelName = values["ch_name"] ?? ""
        recordedAt = values["rec_day"] ?? ""
        genre = values["genre"] ?? ""
        titleTime = Int(values["title_time"] ?? "") ?? 0
        chapterNumber = Int(values["chapter_no"] ?? "") ?? 0
        chapterTime = Int(values["chapter_time"] ?? "") ?? 0
        chapterName = values["chapter_name"] ?? ""
    }

    /// 録画番組を再生しているか
    public var isPlayingRecording: Bool {
        totalTime > 0 || !titleName.isEmpty
    }
}

extension Int {
    /// 秒数を `h:mm:ss` / `m:ss` 形式にする
    public var formattedDuration: String {
        let h = self / 3600, m = (self % 3600) / 60, s = self % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
