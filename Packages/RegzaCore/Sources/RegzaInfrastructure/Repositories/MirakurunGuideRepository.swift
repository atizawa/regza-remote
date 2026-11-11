import Foundation
import Observation
import RegzaDomain

/// 番組表 (GuideRepositoryProtocol の実装)。録画サーバー Mirakurun から読む
@MainActor
@Observable
public final class MirakurunGuideRepository: GuideRepositoryProtocol {
    @ObservationIgnored private let store: any RegzaConnectionStore
    @ObservationIgnored private var client: MirakurunAPIClient
    /// 1 チャンネルの番組表で読んだ番組 (番組の id から引くため)
    @ObservationIgnored private var channelPrograms: [String: [ProgramData]] = [:]

    public private(set) var guideHost: String
    public private(set) var guidePrograms: [String: [ProgramData]] = [:]
    public private(set) var guideProgramsLoadedAt: Date?

    public init(
        store: any RegzaConnectionStore,
        client: MirakurunAPIClient
    ) {
        self.store = store
        self.client = client
        guideHost = client.host
    }

    public func saveGuideHost(_ host: String) async {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != guideHost else { return }
        store.guideHost = host
        guideHost = host
        client = client.replacingHost(host)
        channelPrograms = [:]
        guidePrograms = [:]
        guideProgramsLoadedAt = nil
    }

    private func guideClient() -> MirakurunAPIClient? {
        hasGuide ? client : nil
    }

    /// 全チャンネルの番組を読む。数 MB あるので 30 分に 1 回まで
    public func loadGuidePrograms() async {
        guard let guide = guideClient() else { return }
        if let guideProgramsLoadedAt, Date().timeIntervalSince(guideProgramsLoadedAt) < 30 * 60 { return }
        guard let programs = try? await guide.request(MirakurunAllProgramsRequest()) else { return }
        guard guide === client else { return }
        guidePrograms = Self.byChannel(programs)
        guideProgramsLoadedAt = Date()
    }

    static func byChannel(_ programs: [ProgramData]) -> [String: [ProgramData]] {
        Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
    }

    public func programs(channelCode: String) async throws(RegzaError) -> [ProgramData] {
        guard let guide = guideClient() else { throw .notConfigured }
        do {
            guard let ids = BroadcastID.ids(channelCode: channelCode) else { return [] }
            let now = Date()
            let programs = try await guide.request(MirakurunChannelProgramsRequest(networkID: ids.networkId, serviceID: ids.serviceId))
                .filter { $0.end > now }
            guard guide === client else { throw RegzaError.notConfigured }
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
