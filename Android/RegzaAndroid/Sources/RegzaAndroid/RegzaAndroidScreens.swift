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

/// 番組 (MirakurunProgram に、画面に出す表記を足したもの)
public struct RegzaAndroidProgram {
    public var id: Int
    public var channelCode: String
    public var name: String
    public var description: String
    /// 1970 年からの秒
    public var start: Double
    public var end: Double
    /// 「13:00」
    public var startText: String
    /// 「11月7日(土) 13:00 〜 13:45 · 45分」
    public var timeText: String
    public var genreName: String?
    /// ARIB のジャンルの大分類 (0〜15)。なければ -1
    public var genre: Int
    public var isOnAir: Bool
    public var isReserved: Bool
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
    public var bands: [RegzaChannel.Band]
    public var band: RegzaChannel.Band?
    public var rows: [RegzaAndroidChannelRow]
}

public struct RegzaAndroidChannelRow {
    public var channel: RegzaChannel
    public var programName: String?
    public var isNowPlaying: Bool
    /// 番組表を開ける
    public var hasPrograms: Bool
    /// 控えめに出す (同じ放送局のサブチャンネル)
    public var isSubchannel: Bool
}

/// 新聞のテレビ欄のような番組表 (GuideGridViewModel.State)。選んでいる日の 24 時間分だけを入れる
public struct RegzaAndroidGuide {
    /// 番組表 (Mirakurun) が設定されている
    public var hasGuide: Bool
    public var hasLoaded: Bool
    public var canSearch: Bool
    public var bands: [RegzaChannel.Band]
    public var band: RegzaChannel.Band?
    public var days: [RegzaAndroidDay]
    /// 表に出す時間 (1970 年からの秒)。今日は今の時刻の正時から、ほかの日は朝 4 時から 24 時間
    public var windowStart: Double
    public var windowEnd: Double
    /// 表の左端に出す時刻 (朝 4 時より前は 24〜27 時と書く)
    public var hourLabels: [String]
    /// 今日を見ている (今の時刻の線を出す)
    public var isToday: Bool
    public var columns: [RegzaAndroidGuideColumn]
}

public struct RegzaAndroidDay {
    /// 「今日」「明日」「9(月)」
    public var label: String
    /// "weekday"・"saturday"・"sunday" (土曜は青、日曜は赤で出す)
    public var kind: String
    public var isSelected: Bool
}

public struct RegzaAndroidGuideColumn {
    public var channel: RegzaChannel
    public var programs: [RegzaAndroidProgram]
}

/// 1 チャンネルの番組表 (ProgramListViewModel.State)
public struct RegzaAndroidProgramList {
    public var channelName: String
    /// 読み込み済み (まだなら読み込み中を出す)
    public var isLoaded: Bool
    public var loadErrorMessage: String?
    public var days: [RegzaAndroidProgramDay]
}

public struct RegzaAndroidProgramDay {
    /// 「11月7日(土)」
    public var label: String
    public var programs: [RegzaAndroidProgram]
}

/// 番組の詳細 (ProgramDetailViewModel.State)
public struct RegzaAndroidProgramDetail {
    public var program: RegzaAndroidProgram
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
    public var canStartOver: Bool
    /// 番組内容・出演者など
    public var extended: [RegzaAndroidTextItem]
}

public struct RegzaAndroidTextItem {
    public var title: String
    public var text: String
}

/// 録画予約の一覧 (ReservationListViewModel.State)
public struct RegzaAndroidReservations {
    public var hasLoaded: Bool
    public var loadErrorMessage: String?
    public var cancelError: String?
    /// 録画の予定があるもの (時刻順)
    public var scheduled: [RegzaAndroidReservation]
    /// 次の回を待っている連ドラ予約
    public var waiting: [RegzaAndroidReservation]
}

public struct RegzaAndroidReservation {
    public var id: String
    public var title: String
    /// 「11月7日(土) 16:30 〜 17:00」
    public var timeText: String
    /// 「毎週」など
    public var repeatLabel: String?
    public var channelName: String?
    public var isRecording: Bool
}

/// 番組表の検索 (GuideSearchViewModel.State)
public struct RegzaAndroidSearch {
    public var text: String
    public var isBlank: Bool
    public var isLiteral: Bool
    public var isIndexing: Bool
    /// 読み取った条件 (「明日」「18時〜」「スポーツ」)。removeCondition には何番目かを渡す
    public var conditions: [String]
    public var results: [RegzaAndroidSearchRow]
}

public struct RegzaAndroidSearchRow {
    public var program: RegzaAndroidProgram
    public var channelName: String
    /// 「11/5(木) 21:00〜」。放送中は「放送中 〜21:54」
    public var timeText: String
    /// なぜ見つかったか (「〇〇 が出演」など)
    public var reason: String?
}

// MARK: - ViewModel の state から作る

/// 見えている画面の ViewModel の state。前と同じなら Kotlin に渡し直さない
enum ScreenKey: Equatable {
    case remote
    case channels(ChannelListViewModel.State)
    case guide(GuideGridViewModel.State, band: RegzaChannel.Band?, window: ClosedRange<Date>)
    case reservations(ReservationListViewModel.State)
    case programs(ProgramListViewModel.State)
    case detail(ProgramDetailViewModel.State)
    case search(GuideSearchViewModel.State)
}

enum AndroidFormat {
    static let locale = Locale(identifier: "ja_JP")

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).month().day().weekday())
    }

    /// 「11月7日(土) 13:00 〜 13:45」
    static func range(_ start: Date, _ end: Date) -> String {
        "\(day(start)) \(time(start)) 〜 \(time(end))"
    }

    static func program(_ program: MirakurunProgram, isReserved: Bool, now: Date = Date()) -> RegzaAndroidProgram {
        let minutes = Int(program.end.timeIntervalSince(program.start) / 60)
        return RegzaAndroidProgram(
            id: program.id,
            channelCode: program.channelCode,
            name: program.name,
            description: program.description,
            start: program.start.timeIntervalSince1970,
            end: program.end.timeIntervalSince1970,
            startText: time(program.start),
            timeText: "\(range(program.start, program.end)) · \(minutes)分",
            genreName: program.genreName,
            genre: program.genres.first ?? -1,
            isOnAir: program.isOnAir(at: now),
            isReserved: isReserved
        )
    }
}

extension RegzaAndroidScreen {
    init(_ key: ScreenKey, programs record: (MirakurunProgram, RegzaChannel) -> Void) {
        switch key {
        case .remote:
            self.init(kind: "remote")
        case .channels(let state):
            self.init(kind: "channels", channelList: RegzaAndroidChannelList(
                isLoading: state.isLoading,
                loadErrorMessage: state.loadErrorMessage,
                tuneError: state.tuneError,
                tuningChannelCode: state.tuning?.code,
                bands: state.bands,
                band: state.band,
                rows: state.rows.map {
                    RegzaAndroidChannelRow(
                        channel: $0.channel, programName: $0.programName, isNowPlaying: $0.isNowPlaying,
                        hasPrograms: $0.hasPrograms, isSubchannel: $0.isSubchannel
                    )
                }
            ))
        case .guide(let state, let band, let window):
            let now = Date()
            let hours = (0..<GuideGridViewModel.hours).map {
                "\(BroadcastDay.hour(of: window.lowerBound.addingTimeInterval(TimeInterval($0 * 3600))))"
            }
            self.init(kind: "guide", guide: RegzaAndroidGuide(
                hasGuide: state.hasGuide,
                hasLoaded: state.hasLoaded,
                canSearch: state.canSearch,
                bands: state.bands,
                band: band,
                days: state.days.map {
                    RegzaAndroidDay(label: $0.label, kind: "\($0.kind)", isSelected: $0.day == state.selectedDay)
                },
                windowStart: window.lowerBound.timeIntervalSince1970,
                windowEnd: window.upperBound.timeIntervalSince1970,
                hourLabels: hours,
                isToday: state.selectedDay == nil,
                columns: state.columns.map { column in
                    RegzaAndroidGuideColumn(
                        channel: column.channel,
                        programs: column.cells
                            .filter { $0.program.end > window.lowerBound && $0.program.start < window.upperBound }
                            .map { cell in
                                record(cell.program, column.channel)
                                return AndroidFormat.program(cell.program, isReserved: cell.isReserved, now: now)
                            }
                    )
                }
            ))
        case .reservations(let state):
            func row(_ row: ReservationListViewModel.Row) -> RegzaAndroidReservation {
                RegzaAndroidReservation(
                    id: row.reservation.id,
                    title: row.reservation.title,
                    timeText: AndroidFormat.range(row.reservation.start, row.reservation.end),
                    repeatLabel: row.reservation.repeatLabel,
                    channelName: row.channelName,
                    isRecording: row.isRecording
                )
            }
            self.init(kind: "reservations", reservations: RegzaAndroidReservations(
                hasLoaded: state.hasLoaded,
                loadErrorMessage: state.loadErrorMessage,
                cancelError: state.cancelError,
                scheduled: state.scheduled.map(row),
                waiting: state.waiting.map(row)
            ))
        case .programs(let state):
            self.init(kind: "programs", programs: RegzaAndroidProgramList(
                channelName: state.channel.name,
                isLoaded: state.days != nil,
                loadErrorMessage: state.loadErrorMessage,
                days: (state.days ?? []).map { day in
                    RegzaAndroidProgramDay(label: AndroidFormat.day(day.day), programs: day.rows.map { row in
                        record(row.program, state.channel)
                        return AndroidFormat.program(row.program, isReserved: row.isReserved)
                    })
                }
            ))
        case .detail(let state):
            self.init(kind: "detail", detail: RegzaAndroidProgramDetail(
                program: AndroidFormat.program(state.program, isReserved: state.isReserved),
                channelName: state.channel.name,
                isTuning: state.isTuning,
                isReserving: state.reserving != nil,
                message: state.message,
                reservedText: state.reservedText,
                isReserved: state.isReserved,
                isSeriesReservation: state.reservationIsSeries == true,
                canTune: state.canTune,
                canReserve: state.canReserve,
                canStartOver: state.canStartOver,
                extended: state.program.extended.map { RegzaAndroidTextItem(title: $0.title, text: $0.text) }
            ))
        case .search(let state):
            self.init(kind: "search", search: RegzaAndroidSearch(
                text: state.text,
                isBlank: state.isBlank,
                isLiteral: state.isLiteral,
                isIndexing: state.isIndexing,
                conditions: state.conditions.map(\.label),
                results: state.results.map { row in
                    record(row.program, row.channel)
                    return RegzaAndroidSearchRow(
                        program: AndroidFormat.program(row.program, isReserved: row.isReserved),
                        channelName: row.channel.name,
                        timeText: row.timeText,
                        reason: row.reason
                    )
                }
            ))
        }
    }
}
