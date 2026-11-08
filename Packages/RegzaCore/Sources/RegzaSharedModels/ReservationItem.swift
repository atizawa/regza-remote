import Foundation

/// 録画予約の一覧に出す 1 件 (UI で使う形)。RecordingUseCase が Domain の RegzaReservation から作る
public struct ReservationItem: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// 「11月7日(土) 16:30 〜 17:00」
    public var timeText: String
    /// 「毎週」などの繰り返し。繰り返さなければ nil
    public var repeatLabel: String?
    /// 連ドラ予約 (次の回以降も録画する)
    public var isSeries: Bool
    /// 予約したチャンネルの名前。チャンネル一覧を取れなければ nil
    public var channelName: String?
    /// 録画している最中
    public var isRecording: Bool
    /// 録画の予定がある (録画中も含む)。連ドラ予約で次の回を待っているものは false
    public var isScheduled: Bool

    public init(
        id: String, title: String, timeText: String, repeatLabel: String?, isSeries: Bool,
        channelName: String?, isRecording: Bool, isScheduled: Bool
    ) {
        self.id = id
        self.title = title
        self.timeText = timeText
        self.repeatLabel = repeatLabel
        self.isSeries = isSeries
        self.channelName = channelName
        self.isRecording = isRecording
        self.isScheduled = isScheduled
    }
}
