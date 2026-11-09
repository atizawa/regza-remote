import Foundation
import RegzaApp

// いま見えている画面の状態 (RegzaAndroidApp.screen / nextScreen が返す)。
// 時刻などの表記は iOS と同じものを Swift で作り、Kotlin は並べるだけにする

/// いま見えている画面。kind に合わせて、どれか 1 つだけがある
public struct RegzaAndroidScreen {
    /// どのタブの画面か
    public var tab: AppTab
    /// タブの path のどの画面か。タブの最初の画面なら nil (Compose の back stack の、どの画面の state かを見分ける)
    public var route: AppRoute?
    /// "remote"・"guide"・"channels"・"reservations" (タブの最初の画面)、
    /// "programs" (1 チャンネルの番組表)・"detail" (番組の詳細)・"search" (番組表の検索)
    public var kind: String
    /// チャンネル一覧の画面の state (ChannelListViewModel.State をそのまま渡す)
    public var channelList: ChannelListState?
    /// 番組表の画面の state (GuideGridViewModel.State をそのまま渡す)
    public var guide: GuideGridState?
    /// 録画予約の一覧の画面の state (ReservationListViewModel.State をそのまま渡す)
    public var reservations: ReservationListState?
    /// 1 チャンネルの番組表の画面の state (ProgramListViewModel.State をそのまま渡す)
    public var programs: ProgramListState?
    /// 番組の詳細の画面の state (ProgramDetailViewModel.State をそのまま渡す)
    public var detail: ProgramDetailState?
    /// 番組表の検索の画面の state (GuideSearchViewModel.State をそのまま渡す)
    public var search: GuideSearchState?
}

// MARK: - ViewModel の state から作る

/// 見えている画面 (タブと path の画面) と、その ViewModel の state。前と同じなら Kotlin に渡し直さない
struct ScreenKey: Equatable {
    var tab: AppTab
    var route: AppRoute?
    var content: ScreenContent
}

/// 見えている画面の ViewModel の state
enum ScreenContent: Equatable {
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
        let (tab, route) = (key.tab, key.route)
        switch key.content {
        case .remote:
            self.init(tab: tab, route: route, kind: "remote")
        case .channels(let state):
            self.init(tab: tab, route: route, kind: "channels", channelList: state)
        case .guide(let state):
            self.init(tab: tab, route: route, kind: "guide", guide: state)
        case .reservations(let state):
            self.init(tab: tab, route: route, kind: "reservations", reservations: state)
        case .programs(let state):
            self.init(tab: tab, route: route, kind: "programs", programs: state)
        case .detail(let state):
            self.init(tab: tab, route: route, kind: "detail", detail: state)
        case .search(let state):
            self.init(tab: tab, route: route, kind: "search", search: state)
        }
    }
}

/// URL を文字列にする (ライブ視聴の LivePlayerPhase.ready の URL を ExoPlayer に渡す)。
/// swift-java は enum の値にしか使っていない型の Java のクラスを作らないので、ここで URL を使って作らせる役目もある
public func regzaURLString(_ url: URL) -> String { url.absoluteString }
