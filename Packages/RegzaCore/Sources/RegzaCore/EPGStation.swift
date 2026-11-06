import Foundation

/// 録画サーバー EPGStation の放送のライブ配信 (HLS)。認証は不要。
///
/// 1. `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼むと番号 (streamId) が返る
/// 2. 変換が始まるまで十数秒かかる。`/streamfiles/stream{番号}.m3u8` に映像の部分 (.ts) が載ったら再生できる
/// 3. 見ている間は `PUT /api/streams/:id/keep` で知らせ、終わったら `DELETE /api/streams/:id` で止めてチューナーを空ける
///
/// 同時に変換できる数に上限がある構成では、上限に達していると配信が始まらない (準備できないまま残る)
public final class EPGStation: Sendable {
    public static let defaultPort = 8888

    /// `192.168.0.2` か `192.168.0.2:8888`
    public let host: String
    private let timeout: TimeInterval

    public init(host: String, timeout: TimeInterval = 10) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timeout = timeout
    }

    /// EPGStation のチャンネル ID (Mirakurun のサービス ID と同じ)。テレビのチャンネルの ID から求める
    public static func channelID(channelCode: String) -> Int? {
        Mirakurun.ids(channelCode: channelCode).map { $0.networkId * 100_000 + $0.serviceId }
    }

    /// ライブ配信を頼み、配信の番号を返す。`mode` は EPGStation の設定の画質の順番 (0 が最初の画質)
    public func startLiveStream(channelID: Int, mode: Int = 0) async throws -> Int {
        let data = try await request("GET", "/api/streams/live/\(channelID)/hls", query: "mode=\(mode)")
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamID = object["streamId"] as? Int
        else { throw RegzaError.unsupported }
        return streamID
    }

    public func playlistURL(streamID: Int) -> URL? {
        url("/streamfiles/stream\(streamID).m3u8", query: nil)
    }

    /// 再生できるようになるまで待つ。`timeout` 秒たっても準備できなければ失敗にする
    public func waitUntilReady(streamID: Int, timeout: TimeInterval = 60) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if let data = try? await request("GET", "/streamfiles/stream\(streamID).m3u8"),
               String(decoding: data, as: UTF8.self).contains(".ts") {
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
        _ = try await request("PUT", "/api/streams/\(streamID)/keep")
    }

    /// EPGStation で動いている配信 (ほかの端末のものも含む)
    public struct Stream: Sendable, Equatable {
        public var id: Int
        /// 変換が始まって再生できる状態か。上限などで始まらなかった配信は false のまま残る
        public var isEnabled: Bool
    }

    public func streams() async throws -> [Stream] {
        let data = try await request("GET", "/api/streams", query: "isHalfWidth=true")
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["items"] as? [[String: Any]]
        else { throw RegzaError.unsupported }
        return items.compactMap { item in
            (item["streamId"] as? Int).map { Stream(id: $0, isEnabled: item["isEnable"] as? Bool ?? false) }
        }
    }

    /// 配信を止めてチューナーを空ける。
    /// EPGStation は keep が途切れても配信を自動では止めない (160 秒待っても残ることを確認) ので、必ずこちらから止める
    public func stop(streamID: Int) async throws {
        _ = try await request("DELETE", "/api/streams/\(streamID)")
    }

    /// EPGStation が応答するか
    public func isAvailable() async -> Bool {
        guard let data = try? await request("GET", "/api/version"),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["version"] != nil
    }

    /// 同じネットワークで EPGStation が動いているアドレスを探す
    public static func find(timeout: TimeInterval = 1.5) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask { await EPGStation(host: host, timeout: timeout).isAvailable() ? host : nil }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask { await EPGStation(host: next, timeout: timeout).isAvailable() ? next : nil }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }

    private func url(_ path: String, query: String?) -> URL? {
        let authority = host.contains(":") ? host : "\(host):\(Self.defaultPort)"
        return URL(string: "http://\(authority)\(path)" + (query.map { "?\($0)" } ?? ""))
    }

    private func request(_ method: String, _ path: String, query: String? = nil) async throws -> Data {
        guard !host.isEmpty else { throw RegzaError.notConfigured }
        guard let url = url(path, query: query) else { throw RegzaError.invalidHost }
        let response = try await RegzaHTTP.transport.send(HTTPRequest(method: method, url: url, timeout: timeout))
        guard (200..<300).contains(response.statusCode) else { throw RegzaError.httpStatus(response.statusCode) }
        return response.body
    }
}
