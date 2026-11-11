import Foundation
import RegzaDomain

/// 録画サーバー Mirakurun から番組表を読む。認証は不要。
///
/// テレビの v2 API は番組名を返さないので、放送中の番組名と番組表はこちらから取る。
/// テレビと Mirakurun は同じ放送波の ID (network_id / service_id / event_id) を使っているので、変換して照らし合わせられる。
public final class Mirakurun: Sendable {
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

    /// 1 番組。テレビの `epg_content_id` から `programID(epgContentID:)` で求めた ID を渡す
    public func program(id: Int) async throws -> MirakurunProgram {
        try JSONDecoder().decode(MirakurunProgram.self, from: try await get("/api/programs/\(id)"))
    }

    /// 1 チャンネルの番組 (8 日分ほど)。時刻順
    public func programs(channelCode: String) async throws -> [MirakurunProgram] {
        guard let (networkId, serviceId) = BroadcastID.ids(channelCode: channelCode) else { return [] }
        let data = try await get("/api/programs", query: "networkId=\(networkId)&serviceId=\(serviceId)")
        return try JSONDecoder().decode([MirakurunProgram].self, from: data).sorted { $0.start < $1.start }
    }

    /// 全チャンネルの番組。数 MB になるので、必要なときだけ呼ぶ
    public func allPrograms() async throws -> [MirakurunProgram] {
        try JSONDecoder().decode([MirakurunProgram].self, from: try await get("/api/programs"))
    }

    /// Mirakurun が応答するか
    public func isAvailable() async -> Bool {
        guard let data = try? await get("/api/version"),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["current"] != nil
    }

    private func get(_ path: String, query: String? = nil) async throws -> Data {
        guard !host.isEmpty else { throw RegzaError.notConfigured }
        let authority = host.contains(":") ? host : "\(host):\(Self.defaultPort)"
        guard let url = URL(string: "http://\(authority)\(path)" + (query.map { "?\($0)" } ?? "")) else {
            throw RegzaError.invalidHost
        }
        let response = try await transport.send(HTTPRequest(url: url, timeout: timeout))
        guard (200..<300).contains(response.statusCode) else { throw RegzaError.httpStatus(response.statusCode) }
        // 番組の説明に入っていた制御文字を、そのまま返すことがある (LenientJSON)
        return LenientJSON.escapingControlCharactersInStrings(response.body)
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
                group.addTask { await Mirakurun(host: host, timeout: timeout).isAvailable() ? host : nil }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask { await Mirakurun(host: next, timeout: timeout).isAvailable() ? next : nil }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }
}
