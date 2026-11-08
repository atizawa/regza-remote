import Foundation

/// 番組表 (Mirakurun): 全局の番組表・1 チャンネルの番組表・放送中の番組
@MainActor
public final class GuideUseCase {
    private let guide: any GuideRepository

    public init(guide: any GuideRepository) {
        self.guide = guide
    }

    /// Mirakurun のアドレス。未設定なら空
    public var guideHost: String { guide.guideHost }
    public var hasGuide: Bool { guide.hasGuide }
    /// 全局の番組を、チャンネルの ID ごとに時刻順で持つ
    public var guidePrograms: [String: [MirakurunProgram]] { guide.guidePrograms }
    /// 番組表を読み込んだ時刻 (検索の索引を作り直すかを決めるのに使う)
    public var guideProgramsLoadedAt: Date? { guide.guideProgramsLoadedAt }

    public func loadGuidePrograms() async {
        await guide.loadGuidePrograms()
    }

    /// 1 チャンネルの番組表 (放送中の番組から)
    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        try await guide.programs(for: channel)
    }

    /// そのチャンネルでいま放送中の番組
    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guide.currentProgram(for: channel, at: date)
    }

    public func saveGuideHost(_ host: String) async {
        await guide.saveGuideHost(host)
    }
}
