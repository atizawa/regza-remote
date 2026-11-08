import Foundation

/// 番組表 (録画サーバー Mirakurun)。全局の番組表は、読み込んだものを持っておく
@MainActor
public protocol GuideRepositoryProtocol: AnyObject {
    /// Mirakurun のアドレス。未設定なら空
    var guideHost: String { get }
    /// 全局の番組を、チャンネルの ID ごとに時刻順で持つ (読み込んだもの)
    var guidePrograms: [String: [MirakurunProgram]] { get }
    /// 番組表を読み込んだ時刻 (検索の索引を作り直すかを決めるのに使う)
    var guideProgramsLoadedAt: Date? { get }

    /// 全局の番組表を読む。数 MB あるので、読み込んでから間がなければ読み直さない
    func loadGuidePrograms() async
    /// 1 チャンネルの番組表 (放送中の番組から)。読んだ番組は、番組の id から引けるように覚えておく
    func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram]
    /// 全局の番組表か、1 チャンネルの番組表で読んだ番組
    func program(id: Int, channelCode: String) -> MirakurunProgram?
    /// アドレスを保存する。変わったら、読み込んだ番組表を捨てる
    func saveGuideHost(_ host: String) async
}

extension GuideRepositoryProtocol {
    public var hasGuide: Bool { !guideHost.isEmpty }

    /// そのチャンネルでいま放送中の番組
    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guidePrograms[channel.code]?.first { $0.isOnAir(at: date) }
    }
}
