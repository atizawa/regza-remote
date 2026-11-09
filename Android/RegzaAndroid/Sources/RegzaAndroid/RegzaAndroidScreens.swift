import Foundation
import RegzaApp

// いま見えている画面の状態 (RegzaAndroidApp.screen / nextScreen が返す)。
// 時刻などの表記は iOS と同じものを Swift で作り、Kotlin は並べるだけにする

/// いま見えている画面。kind に合わせて、どれか 1 つだけがある
public struct RegzaAndroidScreen {
    /// "remote"・"guide"・"channels"・"reservations" (タブの最初の画面)、
    /// "programs" (1 チャンネルの番組表)・"detail" (番組の詳細)・"search" (番組表の検索)
    public var kind: String
    public var channelList: RegzaAndroidChannelList?
    public var guide: RegzaAndroidGuide?
    public var reservations: RegzaAndroidReservations?
    public var programs: RegzaAndroidProgramList?
    public var detail: RegzaAndroidProgramDetail?
    public var search: RegzaAndroidSearch?
}

/// チャンネル一覧の画面 (ChannelListViewModel.State)
public struct RegzaAndroidChannelList {
    public var isLoading: Bool
    /// 一覧の代わりに出す、取得できなかった説明
    public var loadErrorMessage: String?
    /// 切り替えられなかったときの説明
    public var tuneError: String?
    /// 切り替え中のチャンネルのコード
    public var tuningChannelCode: String?
    /// アプリで見られる (ライブ視聴を設定している)
    public var canStream: Bool
    public var bands: [BroadcastBand]
    public var band: BroadcastBand?
    public var rows: [ChannelItem]
}

/// 新聞のテレビ欄のような番組表 (GuideGridViewModel.State)。選んでいる日の 24 時間分だけを入れる
public struct RegzaAndroidGuide {
    /// 番組表 (Mirakurun) が設定されている
    public var hasGuide: Bool
    public var hasLoaded: Bool
    public var canSearch: Bool
    public var bands: [BroadcastBand]
    public var band: BroadcastBand?
    public var days: [GuideDay]
    /// 選んでいる日 (days の何番目か)
    public var selectedDayIndex: Int
    /// 表に出す時間 (1970 年からの秒)。今日は今の時刻の正時から、ほかの日は朝 4 時から 24 時間。
    /// Date にすると、Date の Java のつなぎを Domain と窓口の両方で作ってしまうので、数値で渡す
    public var windowStart: Double
    public var windowEnd: Double
    /// 表の左端に出す時刻 (朝 4 時より前は 24〜27 時と書く)
    public var hourLabels: [String]
    /// 今日を見ている (今の時刻の線を出す)
    public var isToday: Bool
    public var columns: [GuideColumn]
}

/// 1 チャンネルの番組表 (ProgramListViewModel.State)
public struct RegzaAndroidProgramList {
    public var channelName: String
    /// 読み込み済み (まだなら読み込み中を出す)
    public var isLoaded: Bool
    public var loadErrorMessage: String?
    public var days: [ProgramDay]
}

/// 番組の詳細 (ProgramDetailViewModel.State)
public struct RegzaAndroidProgramDetail {
    public var program: ProgramItem
    /// 番組内容・出演者など
    public var texts: [ProgramTextItem]
    public var channelName: String
    public var isTuning: Bool
    /// 予約・取り消しの途中
    public var isReserving: Bool
    public var message: String?
    /// 「録画予約済み」「連ドラ予約済み」
    public var reservedText: String?
    public var isReserved: Bool
    public var isSeriesReservation: Bool
    public var canTune: Bool
    public var canReserve: Bool
    /// アプリで見られる (放送中で、ライブ視聴を設定している)
    public var canStream: Bool
    public var canStartOver: Bool
}

/// 録画予約の一覧 (ReservationListViewModel.State)
public struct RegzaAndroidReservations {
    public var hasLoaded: Bool
    /// 読み込み中 (引っ張って読み直したときの印を、終わったら消す)
    public var isLoading: Bool
    public var loadErrorMessage: String?
    public var cancelError: String?
    /// 録画の予定があるもの (時刻順)
    public var scheduled: [ReservationItem]
    /// 次の回を待っている連ドラ予約
    public var waiting: [ReservationItem]
}

/// 番組表の検索 (GuideSearchViewModel.State)
public struct RegzaAndroidSearch {
    public var text: String
    public var isBlank: Bool
    public var isLiteral: Bool
    public var isIndexing: Bool
    /// 読み取った条件 (「明日」「18時〜」「スポーツ」)。removeCondition には何番目かを渡す
    public var conditions: [String]
    public var results: [SearchResultItem]
}

// MARK: - ViewModel の state から作る

/// 見えている画面の ViewModel の state。前と同じなら Kotlin に渡し直さない
enum ScreenKey: Equatable {
    case remote
    case channels(ChannelListViewModel.State)
    case guide(GuideGridViewModel.State, band: BroadcastBand?, window: ClosedRange<Date>)
    case reservations(ReservationListViewModel.State, isLoading: Bool)
    case programs(ProgramListViewModel.State)
    case detail(ProgramDetailViewModel.State)
    case search(GuideSearchViewModel.State)
}

extension RegzaAndroidScreen {
    init(_ key: ScreenKey) {
        switch key {
        case .remote:
            self.init(kind: "remote")
        case .channels(let state):
            self.init(kind: "channels", channelList: RegzaAndroidChannelList(
                isLoading: state.isLoading,
                loadErrorMessage: state.loadErrorMessage,
                tuneError: state.tuneError,
                tuningChannelCode: state.tuningCode,
                canStream: state.canStream,
                bands: state.bands,
                band: state.band,
                rows: state.rows
            ))
        case .guide(let state, let band, let window):
            let hours = (0..<GuideGridViewModel.hours).map {
                "\(BroadcastDay.hour(of: window.lowerBound.addingTimeInterval(TimeInterval($0 * 3600))))"
            }
            self.init(kind: "guide", guide: RegzaAndroidGuide(
                hasGuide: state.hasGuide,
                hasLoaded: state.hasLoaded,
                canSearch: state.canSearch,
                bands: state.bands,
                band: band,
                days: state.days,
                selectedDayIndex: state.days.firstIndex { $0.date == state.selectedDay } ?? 0,
                windowStart: window.lowerBound.timeIntervalSince1970,
                windowEnd: window.upperBound.timeIntervalSince1970,
                hourLabels: hours,
                isToday: state.selectedDay == nil,
                // 表に出す時間の番組だけを渡す (1 週間分を渡すと重い)
                columns: state.columns.map { column in
                    GuideColumn(
                        channelCode: column.channelCode,
                        channelName: column.channelName,
                        programs: column.programs.filter { $0.end > window.lowerBound && $0.start < window.upperBound }
                    )
                }
            ))
        case .reservations(let state, let isLoading):
            self.init(kind: "reservations", reservations: RegzaAndroidReservations(
                hasLoaded: state.hasLoaded,
                isLoading: isLoading,
                loadErrorMessage: state.loadErrorMessage,
                cancelError: state.cancelError,
                scheduled: state.scheduled,
                waiting: state.waiting
            ))
        case .programs(let state):
            self.init(kind: "programs", programs: RegzaAndroidProgramList(
                channelName: state.channelName,
                isLoaded: state.days != nil,
                loadErrorMessage: state.loadErrorMessage,
                days: state.days ?? []
            ))
        case .detail(let state):
            self.init(kind: "detail", detail: RegzaAndroidProgramDetail(
                program: state.program,
                texts: state.texts,
                channelName: state.channelName,
                isTuning: state.isTuning,
                isReserving: state.reserving != nil,
                message: state.message,
                reservedText: state.reservedText,
                isReserved: state.isReserved,
                isSeriesReservation: state.reservationIsSeries == true,
                canTune: state.canTune,
                canReserve: state.canReserve,
                canStream: state.canStream,
                canStartOver: state.canStartOver
            ))
        case .search(let state):
            self.init(kind: "search", search: RegzaAndroidSearch(
                text: state.text,
                isBlank: state.isBlank,
                isLiteral: state.isLiteral,
                isIndexing: state.isIndexing,
                conditions: state.conditions.map(\.label),
                results: state.results
            ))
        }
    }
}
