import Foundation
import Observation
import RegzaDomain

/// 番組表 (GuideRepositoryProtocol の実装)。録画サーバー Mirakurun から読む
@MainActor
@Observable
public final class MirakurunGuideRepository: GuideRepositoryProtocol {
    @ObservationIgnored private let store: any RegzaConnectionStore
    @ObservationIgnored private let transport: any HTTPTransport
    /// アドレスが変わったとき (テレビの Repository に、番組名を補う番組表を差し替えてもらう)
    @ObservationIgnored private let onHostChange: @MainActor (String) async -> Void
    @ObservationIgnored private var client: Mirakurun?
    /// 1 チャンネルの番組表で読んだ番組 (番組の id から引くため)
    @ObservationIgnored private var channelPrograms: [String: [MirakurunProgram]] = [:]

    public private(set) var guideHost: String
    public private(set) var guidePrograms: [String: [MirakurunProgram]] = [:]
    public private(set) var guideProgramsLoadedAt: Date?

    public init(
        store: any RegzaConnectionStore,
        transport: any HTTPTransport = RegzaHTTP.transport,
        onHostChange: @escaping @MainActor (String) async -> Void = { _ in }
    ) {
        self.store = store
        self.transport = transport
        self.onHostChange = onHostChange
        guideHost = store.guideHost
    }

    public func saveGuideHost(_ host: String) async {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != guideHost else { return }
        store.guideHost = host
        guideHost = host
        client = nil
        channelPrograms = [:]
        guidePrograms = [:]
        guideProgramsLoadedAt = nil
        await onHostChange(host)
    }

    private func guideClient() -> Mirakurun? {
        guard hasGuide else { return nil }
        if let client, client.host == guideHost { return client }
        let client = Mirakurun(host: guideHost, transport: transport)
        self.client = client
        return client
    }

    /// 全チャンネルの番組を読む。数 MB あるので 30 分に 1 回まで
    public func loadGuidePrograms() async {
        guard let guide = guideClient() else { return }
        if let guideProgramsLoadedAt, Date().timeIntervalSince(guideProgramsLoadedAt) < 30 * 60 { return }
        guard let programs = try? await guide.allPrograms() else { return }
        guidePrograms = Self.byChannel(programs)
        guideProgramsLoadedAt = Date()
    }

    static func byChannel(_ programs: [MirakurunProgram]) -> [String: [MirakurunProgram]] {
        Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
    }

    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        guard let guide = guideClient() else { throw .notConfigured }
        do {
            let now = Date()
            let programs = try await guide.programs(channelCode: channel.code).filter { $0.end > now }
            channelPrograms[channel.code] = programs
            return programs
        } catch {
            throw RegzaError(error)
        }
    }

    public func program(id: Int, channelCode: String) -> MirakurunProgram? {
        guidePrograms[channelCode]?.first { $0.id == id } ?? channelPrograms[channelCode]?.first { $0.id == id }
    }
}
