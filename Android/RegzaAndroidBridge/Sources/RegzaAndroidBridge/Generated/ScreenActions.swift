// ScreenGlue (Android/ScreenGlue の screen-glue) が作る (手で直さない)
import RegzaApp

// MARK: - 操作

extension RegzaAndroidApp {
    /// AppViewModel に送る
    public func sendAppAction(_ action: AppAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// AppViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: AppAction) {
        route { ($0 as? AppViewModel)?.send(action) != nil }
    }

    /// ChannelListViewModel に送る
    public func sendChannelListAction(_ action: ChannelListAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// ChannelListViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: ChannelListAction) {
        route { ($0 as? ChannelListViewModel)?.send(action) != nil }
    }

    /// GuideGridViewModel に送る
    public func sendGuideGridAction(_ action: GuideGridAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// GuideGridViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: GuideGridAction) {
        route { ($0 as? GuideGridViewModel)?.send(action) != nil }
    }

    /// GuideSearchViewModel に送る
    public func sendGuideSearchAction(_ action: GuideSearchAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// GuideSearchViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: GuideSearchAction) {
        route { ($0 as? GuideSearchViewModel)?.send(action) != nil }
    }

    /// LivePlayerViewModel に送る
    public func sendLivePlayerAction(_ action: LivePlayerAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// LivePlayerViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: LivePlayerAction) {
        route { ($0 as? LivePlayerViewModel)?.send(action) != nil }
    }

    /// NowPlayingViewModel に送る
    public func sendNowPlayingAction(_ action: NowPlayingAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// NowPlayingViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: NowPlayingAction) {
        route { ($0 as? NowPlayingViewModel)?.send(action) != nil }
    }

    /// ProgramDetailViewModel に送る
    public func sendProgramDetailAction(_ action: ProgramDetailAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// ProgramDetailViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: ProgramDetailAction) {
        route { ($0 as? ProgramDetailViewModel)?.send(action) != nil }
    }

    /// ProgramListViewModel に送る
    public func sendProgramListAction(_ action: ProgramListAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// ProgramListViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: ProgramListAction) {
        route { ($0 as? ProgramListViewModel)?.send(action) != nil }
    }

    /// RemoteViewModel に送る
    public func sendRemoteAction(_ action: RemoteAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// RemoteViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: RemoteAction) {
        route { ($0 as? RemoteViewModel)?.send(action) != nil }
    }

    /// ReservationListViewModel に送る
    public func sendReservationListAction(_ action: ReservationListAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// ReservationListViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: ReservationListAction) {
        route { ($0 as? ReservationListViewModel)?.send(action) != nil }
    }

    /// SettingsViewModel に送る
    public func sendSettingsAction(_ action: SettingsAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// SettingsViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: SettingsAction) {
        route { ($0 as? SettingsViewModel)?.send(action) != nil }
    }
}

// MARK: - state

extension RegzaAndroidApp {
    /// AppViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func appState(route: AppRoute?) async -> AppState? {
        await MainActor.run { self.state(route: route) { ($0 as? AppViewModel)?.state } }
    }

    /// AppViewModel の state が after から変わるまで待って返す
    public func nextAppState(route: AppRoute?, after: AppState?, waitID: Int64) async -> AppState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? AppViewModel)?.state }
    }

    /// ChannelListViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func channelListState(route: AppRoute?) async -> ChannelListState? {
        await MainActor.run { self.state(route: route) { ($0 as? ChannelListViewModel)?.state } }
    }

    /// ChannelListViewModel の state が after から変わるまで待って返す
    public func nextChannelListState(route: AppRoute?, after: ChannelListState?, waitID: Int64) async -> ChannelListState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? ChannelListViewModel)?.state }
    }

    /// GuideGridViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func guideGridState(route: AppRoute?) async -> GuideGridState? {
        await MainActor.run { self.state(route: route) { ($0 as? GuideGridViewModel)?.state } }
    }

    /// GuideGridViewModel の state が after から変わるまで待って返す
    public func nextGuideGridState(route: AppRoute?, after: GuideGridState?, waitID: Int64) async -> GuideGridState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? GuideGridViewModel)?.state }
    }

    /// GuideSearchViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func guideSearchState(route: AppRoute?) async -> GuideSearchState? {
        await MainActor.run { self.state(route: route) { ($0 as? GuideSearchViewModel)?.state } }
    }

    /// GuideSearchViewModel の state が after から変わるまで待って返す
    public func nextGuideSearchState(route: AppRoute?, after: GuideSearchState?, waitID: Int64) async -> GuideSearchState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? GuideSearchViewModel)?.state }
    }

    /// LivePlayerViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func livePlayerState(route: AppRoute?) async -> LivePlayerState? {
        await MainActor.run { self.state(route: route) { ($0 as? LivePlayerViewModel)?.state } }
    }

    /// LivePlayerViewModel の state が after から変わるまで待って返す
    public func nextLivePlayerState(route: AppRoute?, after: LivePlayerState?, waitID: Int64) async -> LivePlayerState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? LivePlayerViewModel)?.state }
    }

    /// NowPlayingViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func nowPlayingState(route: AppRoute?) async -> NowPlayingState? {
        await MainActor.run { self.state(route: route) { ($0 as? NowPlayingViewModel)?.state } }
    }

    /// NowPlayingViewModel の state が after から変わるまで待って返す
    public func nextNowPlayingState(route: AppRoute?, after: NowPlayingState?, waitID: Int64) async -> NowPlayingState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? NowPlayingViewModel)?.state }
    }

    /// ProgramDetailViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func programDetailState(route: AppRoute?) async -> ProgramDetailState? {
        await MainActor.run { self.state(route: route) { ($0 as? ProgramDetailViewModel)?.state } }
    }

    /// ProgramDetailViewModel の state が after から変わるまで待って返す
    public func nextProgramDetailState(route: AppRoute?, after: ProgramDetailState?, waitID: Int64) async -> ProgramDetailState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? ProgramDetailViewModel)?.state }
    }

    /// ProgramListViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func programListState(route: AppRoute?) async -> ProgramListState? {
        await MainActor.run { self.state(route: route) { ($0 as? ProgramListViewModel)?.state } }
    }

    /// ProgramListViewModel の state が after から変わるまで待って返す
    public func nextProgramListState(route: AppRoute?, after: ProgramListState?, waitID: Int64) async -> ProgramListState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? ProgramListViewModel)?.state }
    }

    /// RemoteViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func remoteState(route: AppRoute?) async -> RemoteState? {
        await MainActor.run { self.state(route: route) { ($0 as? RemoteViewModel)?.state } }
    }

    /// RemoteViewModel の state が after から変わるまで待って返す
    public func nextRemoteState(route: AppRoute?, after: RemoteState?, waitID: Int64) async -> RemoteState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? RemoteViewModel)?.state }
    }

    /// ReservationListViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func reservationListState(route: AppRoute?) async -> ReservationListState? {
        await MainActor.run { self.state(route: route) { ($0 as? ReservationListViewModel)?.state } }
    }

    /// ReservationListViewModel の state が after から変わるまで待って返す
    public func nextReservationListState(route: AppRoute?, after: ReservationListState?, waitID: Int64) async -> ReservationListState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? ReservationListViewModel)?.state }
    }

    /// SettingsViewModel の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func settingsState(route: AppRoute?) async -> SettingsState? {
        await MainActor.run { self.state(route: route) { ($0 as? SettingsViewModel)?.state } }
    }

    /// SettingsViewModel の state が after から変わるまで待って返す
    public func nextSettingsState(route: AppRoute?, after: SettingsState?, waitID: Int64) async -> SettingsState? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? SettingsViewModel)?.state }
    }
}

// MARK: - 振る舞いのテストの Android 側の相手

extension RegzaAndroidApp {
    /// 振る舞いのテストの Android 側の相手: 約束事の操作を AppAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractAppAction(path: String, action: String, arguments: String) async -> AppAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? AppAction }
    }

    /// 振る舞いのテストの Android 側の相手: AppState を regza と同じ JSON にする (AppViewModel の見せ方を使う)
    public func contractAppStateJSON(_ state: AppState?) -> String {
        state.map { AppViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を ChannelListAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractChannelListAction(path: String, action: String, arguments: String) async -> ChannelListAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? ChannelListAction }
    }

    /// 振る舞いのテストの Android 側の相手: ChannelListState を regza と同じ JSON にする (ChannelListViewModel の見せ方を使う)
    public func contractChannelListStateJSON(_ state: ChannelListState?) -> String {
        state.map { ChannelListViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を GuideGridAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractGuideGridAction(path: String, action: String, arguments: String) async -> GuideGridAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? GuideGridAction }
    }

    /// 振る舞いのテストの Android 側の相手: GuideGridState を regza と同じ JSON にする (GuideGridViewModel の見せ方を使う)
    public func contractGuideGridStateJSON(_ state: GuideGridState?) -> String {
        state.map { GuideGridViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を GuideSearchAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractGuideSearchAction(path: String, action: String, arguments: String) async -> GuideSearchAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? GuideSearchAction }
    }

    /// 振る舞いのテストの Android 側の相手: GuideSearchState を regza と同じ JSON にする (GuideSearchViewModel の見せ方を使う)
    public func contractGuideSearchStateJSON(_ state: GuideSearchState?) -> String {
        state.map { GuideSearchViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を LivePlayerAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractLivePlayerAction(path: String, action: String, arguments: String) async -> LivePlayerAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? LivePlayerAction }
    }

    /// 振る舞いのテストの Android 側の相手: LivePlayerState を regza と同じ JSON にする (LivePlayerViewModel の見せ方を使う)
    public func contractLivePlayerStateJSON(_ state: LivePlayerState?) -> String {
        state.map { LivePlayerViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を NowPlayingAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractNowPlayingAction(path: String, action: String, arguments: String) async -> NowPlayingAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? NowPlayingAction }
    }

    /// 振る舞いのテストの Android 側の相手: NowPlayingState を regza と同じ JSON にする (NowPlayingViewModel の見せ方を使う)
    public func contractNowPlayingStateJSON(_ state: NowPlayingState?) -> String {
        state.map { NowPlayingViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を ProgramDetailAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractProgramDetailAction(path: String, action: String, arguments: String) async -> ProgramDetailAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? ProgramDetailAction }
    }

    /// 振る舞いのテストの Android 側の相手: ProgramDetailState を regza と同じ JSON にする (ProgramDetailViewModel の見せ方を使う)
    public func contractProgramDetailStateJSON(_ state: ProgramDetailState?) -> String {
        state.map { ProgramDetailViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を ProgramListAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractProgramListAction(path: String, action: String, arguments: String) async -> ProgramListAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? ProgramListAction }
    }

    /// 振る舞いのテストの Android 側の相手: ProgramListState を regza と同じ JSON にする (ProgramListViewModel の見せ方を使う)
    public func contractProgramListStateJSON(_ state: ProgramListState?) -> String {
        state.map { ProgramListViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を RemoteAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractRemoteAction(path: String, action: String, arguments: String) async -> RemoteAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? RemoteAction }
    }

    /// 振る舞いのテストの Android 側の相手: RemoteState を regza と同じ JSON にする (RemoteViewModel の見せ方を使う)
    public func contractRemoteStateJSON(_ state: RemoteState?) -> String {
        state.map { RemoteViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を ReservationListAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractReservationListAction(path: String, action: String, arguments: String) async -> ReservationListAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? ReservationListAction }
    }

    /// 振る舞いのテストの Android 側の相手: ReservationListState を regza と同じ JSON にする (ReservationListViewModel の見せ方を使う)
    public func contractReservationListStateJSON(_ state: ReservationListState?) -> String {
        state.map { ReservationListViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }

    /// 振る舞いのテストの Android 側の相手: 約束事の操作を SettingsAction にする (アプリと同じ道で送るため)。できなければ nil
    public func contractSettingsAction(path: String, action: String, arguments: String) async -> SettingsAction? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? SettingsAction }
    }

    /// 振る舞いのテストの Android 側の相手: SettingsState を regza と同じ JSON にする (SettingsViewModel の見せ方を使う)
    public func contractSettingsStateJSON(_ state: SettingsState?) -> String {
        state.map { SettingsViewModel.introspectionJSON(of: $0) }?.json ?? "null"
    }
}
