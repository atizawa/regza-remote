import Foundation
import Observation
import RegzaDomain

/// 番組表 (GuideRepositoryProtocol の実装)。録画サーバー Mirakurun から読む
@MainActor
@Observable
public final class MirakurunGuideRepository: GuideRepositoryProtocol {
    @ObservationIgnored private let preferencesManager: PreferencesManager
    @ObservationIgnored private var mirakurunAPIClient: MirakurunAPIClient
    /// 1 チャンネルの番組表で読んだ番組 (番組の id から引くため)
    @ObservationIgnored private var channelPrograms: [String: [ProgramData]] = [:]

    public private(set) var guideHost: String
    public private(set) var guidePrograms: [String: [ProgramData]] = [:]
    public private(set) var guideProgramsLoadedAt: Date?

    /// 今の時刻 (読み込んだ時刻と、放送中の番組の判断に使う)
    @ObservationIgnored private let clock: AppClock

    public init(
        preferencesManager: PreferencesManager,
        mirakurunAPIClient: MirakurunAPIClient,
        clock: AppClock
    ) {
        self.preferencesManager = preferencesManager
        self.clock = clock
        self.mirakurunAPIClient = mirakurunAPIClient
        guideHost = mirakurunAPIClient.host
    }

    public func saveGuideHost(_ host: String) async {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != guideHost else { return }
        preferencesManager.setValue(host, forKey: .guideHost)
        guideHost = host
        mirakurunAPIClient = mirakurunAPIClient.replacingHost(host)
        channelPrograms = [:]
        guidePrograms = [:]
        guideProgramsLoadedAt = nil
    }

    private func guideClient() -> MirakurunAPIClient? {
        hasGuide ? mirakurunAPIClient : nil
    }

    /// 全チャンネルの番組を読む。数 MB あるので 30 分に 1 回まで
    public func loadGuidePrograms() async throws(RegzaError) {
        guard let guideAPIClient = guideClient() else { return }
        if let guideProgramsLoadedAt, clock.now.timeIntervalSince(guideProgramsLoadedAt) < 30 * 60 { return }
        let programs: [ProgramData]
        do { programs = try await guideAPIClient.request(MirakurunAllProgramsRequest()) } catch { throw RegzaError(error) }
        // 読んでいる間に番組表の接続先が変わったら、前の接続先の番組は入れない
        guard guideAPIClient === mirakurunAPIClient else { return }
        guidePrograms = Self.byChannel(programs)
        guideProgramsLoadedAt = clock.now
    }

    static func byChannel(_ programs: [ProgramData]) -> [String: [ProgramData]] {
        Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
    }

    public func programs(channelCode: String) async throws(RegzaError) -> [ProgramData] {
        guard let guideAPIClient = guideClient() else { throw .app(.notConfigured) }
        do {
            guard let ids = BroadcastID.ids(channelCode: channelCode) else { return [] }
            let now = clock.now
            let programs = try await guideAPIClient.request(
                MirakurunChannelProgramsRequest(networkID: ids.networkId, serviceID: ids.serviceId)
            )
            .filter { $0.end > now }
            guard guideAPIClient === mirakurunAPIClient else { throw RegzaError.app(.notConfigured) }
            channelPrograms[channelCode] = programs
            return programs
        } catch {
            throw RegzaError(error)
        }
    }

    public func program(id: Int, channelCode: String) -> ProgramData? {
        guidePrograms[channelCode]?.first { $0.id == id } ?? channelPrograms[channelCode]?.first { $0.id == id }
    }
}
