import EPGStationAPI
import Foundation
import RegzaDomain

/// 録画サーバー EPGStation の放送のライブ配信 (HLS)。認証は不要。
///
/// 1. `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼むと番号 (streamId) が返る
/// 2. 変換が始まるまで十数秒かかる。`/streamfiles/stream{番号}.m3u8` に映像の部分 (.ts) が載ったら再生できる
/// 3. 見ている間は `PUT /api/streams/:id/keep` で知らせ、終わったら `DELETE /api/streams/:id` で止めてチューナーを空ける
///
/// 同時に変換できる数に上限がある構成では、上限に達していると配信が始まらない (準備できないまま残る)
public final class EPGStationAPIClient: Sendable {
    public static let defaultPort = ServerPort.epgStation

    /// `192.168.0.2` か `192.168.0.2:8888`
    public let host: String
    private let timeout: TimeInterval
    private let transport: any HTTPTransport

    public init(host: String, timeout: TimeInterval = 10, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
        self.transport = transport
    }

    /// 注入された通信方式とタイムアウトを保ったまま接続先を差し替える。
    public func replacingHost(_ host: String) -> EPGStationAPIClient {
        EPGStationAPIClient(host: host, timeout: timeout, transport: transport)
    }

    /// EPGStation のチャンネル ID (Mirakurun のサービス ID と同じ)。テレビのチャンネルの ID から求める
    public static func channelID(channelCode: String) -> Int? {
        BroadcastID.ids(channelCode: channelCode).map { $0.networkId * 100_000 + $0.serviceId }
    }

    /// ライブ配信を頼み、配信の番号を返す。`mode` は EPGStation の設定の画質の順番 (0 が最初の画質)
    public func startLiveStream(channelID: Int, mode: Int = 0) async throws -> Int {
        try await performOpenAPI {
            try await openAPI().startLiveStream(path: .init(channelId: channelID), query: .init(mode: mode)).ok.body.json.streamId
        }
    }

    public func playlistURL(streamID: Int) -> URL? {
        guard let url = try? recordingServerURL(host: host, defaultPort: Self.defaultPort, template: EPGStationAPI.Servers.Server1.url()),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        components.path = "/streamfiles/stream\(streamID).m3u8"
        return components.url
    }

    /// 再生できるようになるまで待つ。`timeout` 秒たっても準備できなければ失敗にする
    public func waitUntilReady(streamID: Int, timeout: TimeInterval = 60) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if let data = try? await playlist(streamID: streamID),
                String(decoding: data, as: UTF8.self).contains(".ts")
            {
                return
            }
            // 見ていることを知らせながら待つ
            try? await keep(streamID: streamID)
            try await Task.sleep(for: .seconds(1))
        }
        throw RegzaError.network("配信の準備ができませんでした")
    }

    /// まだ見ていることを知らせる (知らせないと EPGStation が配信を止める)
    public func keep(streamID: Int) async throws {
        _ = try await performOpenAPI { try await openAPI().keepStream(path: .init(streamId: streamID)) }
    }

    /// EPGStation で動いている配信 (ほかの端末のものも含む)
    public struct Stream: Sendable, Equatable {
        public var id: Int
        /// 変換が始まって再生できる状態か。上限などで始まらなかった配信は false のまま残る
        public var isEnabled: Bool
    }

    public func streams() async throws -> [Stream] {
        try await performOpenAPI {
            let items = try await openAPI().getStreams(query: .init(isHalfWidth: true)).ok.body.json.items
            return items.compactMap { item in
                item.streamId.map { Stream(id: $0, isEnabled: item.isEnable ?? false) }
            }
        }
    }

    /// 配信を止めてチューナーを空ける。
    /// EPGStation は keep が途切れても配信を自動では止めない (160 秒待っても残ることを確認) ので、必ずこちらから止める
    public func stop(streamID: Int) async throws {
        _ = try await performOpenAPI { try await openAPI().stopStream(path: .init(streamId: streamID)) }
    }

    /// EPGStation が応答するか
    public func isAvailable() async -> Bool {
        (try? await performOpenAPI {
            _ = try await openAPI().getVersion().ok.body.json.version
            return true
        }) ?? false
    }

    /// 同じネットワークで EPGStation が動いているアドレスを探す
    public static func find(timeout: TimeInterval = 1.5) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask { await EPGStationAPIClient(host: host, timeout: timeout).isAvailable() ? host : nil }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask { await EPGStationAPIClient(host: next, timeout: timeout).isAvailable() ? next : nil }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }

    private func openAPI() throws -> EPGStationAPI.Client {
        EPGStationAPI.Client(
            serverURL: try recordingServerURL(host: host, defaultPort: Self.defaultPort, template: EPGStationAPI.Servers.Server1.url()),
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [OpenAPIResponseMiddleware(), OpenAPIJSONMiddleware()]
        )
    }

    /// HLS のプレイリストは REST API の仕様外のファイル。
    private func playlist(streamID: Int) async throws -> Data {
        guard !host.isEmpty else { throw RegzaError.notConfigured }
        guard let url = playlistURL(streamID: streamID) else { throw RegzaError.invalidHost }
        let response = try await transport.send(HTTPRequest(url: url, timeout: timeout))
        guard (200..<300).contains(response.statusCode) else { throw RegzaError.httpStatus(response.statusCode) }
        return response.body
    }
}
