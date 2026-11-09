// scripts/generate-screen-glue.sh が作る (手で直さない)
import RegzaApp

extension RegzaAndroidApp {
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
