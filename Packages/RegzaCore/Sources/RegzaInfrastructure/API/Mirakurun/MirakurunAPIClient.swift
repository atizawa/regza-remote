import Foundation
import MirakurunAPI
import RegzaDomain

/// 録画サーバー Mirakurun から番組表を読む。認証は不要。
///
/// テレビの v2 API は番組名を返さないので、放送中の番組名と番組表はこちらから取る。
/// テレビと Mirakurun は同じ放送波の ID (network_id / service_id / event_id) を使っているので、変換して照らし合わせられる。
public final class MirakurunAPIClient: Sendable {
    public static let defaultPort = ServerPort.mirakurun

    /// `192.168.0.2` か `192.168.0.2:40772`
    public let host: String
    private let timeout: TimeInterval
    private let transport: any HTTPTransport

    public init(host: String, timeout: TimeInterval = 10, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
        self.transport = transport
    }

    /// 注入された通信方式とタイムアウトを保ったまま接続先を差し替える。
    public func replacingHost(_ host: String) -> MirakurunAPIClient {
        MirakurunAPIClient(host: host, timeout: timeout, transport: transport)
    }

    /// 1 番組。テレビの `epg_content_id` から `programID(epgContentID:)` で求めた ID を渡す
    public func program(id: Int) async throws -> MirakurunProgram {
        try await performOpenAPI {
            let program = try await openAPI().getProgram(path: .init(id: id)).ok.body.json
            return try Self.program(program)
        }
    }

    /// 1 チャンネルの番組 (8 日分ほど)。時刻順
    public func programs(channelCode: String) async throws -> [MirakurunProgram] {
        guard let (networkId, serviceId) = BroadcastID.ids(channelCode: channelCode) else { return [] }
        return try await performOpenAPI {
            let programs = try await openAPI().getPrograms(query: .init(networkId: networkId, serviceId: serviceId)).ok.body.json
            return try programs.map(Self.program).sorted { $0.start < $1.start }
        }
    }

    /// 全チャンネルの番組。数 MB になるので、必要なときだけ呼ぶ
    public func allPrograms() async throws -> [MirakurunProgram] {
        try await performOpenAPI {
            let programs = try await openAPI().getPrograms().ok.body.json
            return try programs.map(Self.program)
        }
    }

    /// Mirakurun が応答するか
    public func isAvailable() async -> Bool {
        (try? await performOpenAPI { try await openAPI().checkVersion().ok.body.json.current != nil }) ?? false
    }

    private func openAPI() throws -> MirakurunAPI.Client {
        MirakurunAPI.Client(
            serverURL: try recordingServerURL(host: host, defaultPort: Self.defaultPort, template: MirakurunAPI.Servers.Server1.url()),
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [OpenAPIResponseMiddleware(), OpenAPIJSONMiddleware()]
        )
    }

    /// 生成 DTO を直接 Domain に変換する。番組表全体を JSON に再エンコードしない。
    private static func program(_ source: MirakurunAPI.Components.Schemas.Program) throws -> MirakurunProgram {
        let extended = try (source.extended?.value ?? [:]).map { key, value in
            guard let text = value as? String else { throw RegzaError.unsupported }
            return MirakurunProgram.Extended(title: key, text: text)
        }
        let genres = try (source.genres ?? []).map { genre in
            guard let value = genre.lv1 else { throw RegzaError.unsupported }
            return value
        }
        let startAt = Double(source.startAt)
        let duration = Double(source.duration ?? 0)
        return MirakurunProgram(
            id: source.id, networkId: source.networkId, serviceId: source.serviceId,
            eventId: source.eventId ?? source.id % 100_000,
            start: Date(timeIntervalSince1970: startAt / 1000), end: Date(timeIntervalSince1970: (startAt + duration) / 1000),
            name: source.name ?? "", description: source.description ?? "", extended: extended, genres: genres
        )
    }

    // MARK: - 探す

    /// 同じネットワークで Mirakurun が動いているアドレスを探す
    public static func find(timeout: TimeInterval = 1.5) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask { await MirakurunAPIClient(host: host, timeout: timeout).isAvailable() ? host : nil }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask { await MirakurunAPIClient(host: next, timeout: timeout).isAvailable() ? next : nil }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }
}
