import Foundation
import RegzaApp

// いま見えている画面の状態 (RegzaAndroidApp.screen / nextScreen が返す)。
// 時刻などの表記は iOS と同じものを Swift で作り、Kotlin は並べるだけにする

/// いま見えている画面。kind に合わせて、どれか 1 つだけがある
public struct RegzaAndroidScreen {
    /// "remote"・"guide"・"channels"・"reservations" (タブの最初の画面)、
    /// "programs" (1 チャンネルの番組表)・"detail" (番組の詳細)・"search" (番組表の検索)
    public var kind: String
    /// チャンネル一覧の画面の state (ChannelListViewModel.State をそのまま渡す)
    public var channelList: ChannelListState?
    /// 番組表の画面の state (GuideGridViewModel.State をそのまま渡す)
    public var guide: GuideGridState?
    /// 録画予約の一覧の画面の state (ReservationListViewModel.State をそのまま渡す)
    public var reservations: ReservationListState?
    public var programs: RegzaAndroidProgramList?
    public var detail: RegzaAndroidProgramDetail?
    public var search: RegzaAndroidSearch?
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
    case guide(GuideGridViewModel.State)
    case reservations(ReservationListViewModel.State)
    case programs(ProgramListViewModel.State)
    case detail(ProgramDetailViewModel.State)
    case search(GuideSearchViewModel.State)
}

extension RegzaAndroidScreen {
    @MainActor init(_ key: ScreenKey) {
        switch key {
        case .remote:
            self.init(kind: "remote")
        case .channels(let state):
            self.init(kind: "channels", channelList: state)
        case .guide(let state):
            self.init(kind: "guide", guide: state)
        case .reservations(let state):
            self.init(kind: "reservations", reservations: state)
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

/// URL を文字列にする (ライブ視聴の LivePlayerPhase.ready の URL を ExoPlayer に渡す)。
/// swift-java は enum の値にしか使っていない型の Java のクラスを作らないので、ここで URL を使って作らせる役目もある
public func regzaURLString(_ url: URL) -> String { url.absoluteString }
