public import Foundation

/// 番組表の画面の状態 (GuideGridViewModel.State)
public struct GuideGridState: Equatable, Sendable {
    /// 番組表 (Mirakurun) が設定されている
    public var hasGuide: Bool
    public var hasLoaded: Bool
    /// 検索を出せる (番組表を読み込めたときだけ)
    public var canSearch: Bool
    /// 番組表がある放送の種類
    public var bands: [BroadcastBand]
    /// 選んでいる放送の種類
    public var band: BroadcastBand?
    /// 選んだ放送の局。サブチャンネル (同じリモコン番号の局) は代表のものだけにする。
    /// 番組は表に出す時間 (windowStart〜windowEnd) にかかるものだけにする
    public var columns: [GuideColumn]
    /// 日付の選択肢。最初は今日 (date が nil)、そのあと明日から番組表がある最後の日まで
    public var days: [GuideDay]
    /// 選んでいる日 (その日の朝 4 時)。nil なら今日 (今の時刻から 24 時間)
    public var selectedDay: Date?
    /// 選んでいる日が days の何番目か
    public var selectedDayIndex: Int
    /// 今日を見ている (今の時刻の線を出す)
    public var isToday: Bool
    /// 表に出す時間。今日は今の時刻の正時から、ほかの日は朝 4 時から 24 時間
    public var windowStart: Date
    public var windowEnd: Date
    /// 表の左端に出す正時の時刻 (朝 4 時より前は前の日の続きとして 24〜27 時と書く)
    public var hourLabels: [String]
}
