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

    /// LivePlayerViewModel に送る
    public func sendLivePlayerAction(_ action: LivePlayerAction) {
        Task { @MainActor in self.perform(action) }
    }

    /// LivePlayerViewModel に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: LivePlayerAction) {
        route { ($0 as? LivePlayerViewModel)?.send(action) != nil }
    }
}
