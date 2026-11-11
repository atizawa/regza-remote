import Foundation
import Observation
import RegzaDomain

/// ライブ配信 (StreamRepositoryProtocol の実装)。録画サーバー EPGStation に頼む。
/// このアプリが頼んだ配信の番号は保存先に覚え、アプリが強制終了されて止められなかった配信は、次に開いたときに止める
@MainActor
@Observable
public final class EPGStationStreamRepository: StreamRepositoryProtocol {
    @ObservationIgnored private let store: any RegzaConnectionStore
    @ObservationIgnored private var client: EPGStationAPIClient

    public private(set) var streamHost: String

    public init(store: any RegzaConnectionStore, client: EPGStationAPIClient) {
        self.store = store
        self.client = client
        streamHost = client.host
    }

    /// この Repository の配信先が設定されている。番組表との組み合わせは UseCase が判断する。
    public var canStream: Bool { !streamHost.isEmpty }

    public func saveStreamHost(_ host: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        store.streamHost = host
        streamHost = host
        client = client.replacingHost(host)
    }

    /// 配信を頼む EPGStation。配信できないなら nil
    public func streamServer() -> EPGStationAPIClient? {
        canStream ? client : nil
    }

    public func isPlayable(channelCode: String) -> Bool {
        BroadcastID.ids(channelCode: channelCode) != nil
    }

    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        guard let server = streamServer() else { throw .notConfigured }
        guard let ids = BroadcastID.ids(channelCode: channelCode) else { throw .unsupported }
        let channelID = ids.networkId * 100_000 + ids.serviceId
        let streamID: Int
        do {
            streamID = try await server.request(EPGStationStartStreamRequest(channelID: channelID, mode: 0))
        } catch {
            throw RegzaError(error)
        }
        guard server === client else {
            try? await server.request(EPGStationStopStreamRequest(streamID: streamID))
            throw .notConfigured
        }
        if !store.ownStreamIDs.contains(streamID) { store.ownStreamIDs.append(streamID) }
        return streamID
    }

    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL {
        guard let server = streamServer() else { throw .notConfigured }
        do {
            try await EPGStationStreaming(client: server).waitUntilReady(streamID: streamID)
        } catch {
            throw RegzaError(error)
        }
        guard server === client else { throw .notConfigured }
        guard let url = EPGStationStreaming(client: server).playlistURL(streamID: streamID) else { throw .invalidHost }
        return url
    }

    public func keep(streamID: Int) async {
        try? await streamServer()?.request(EPGStationKeepStreamRequest(streamID: streamID))
    }

    public func stop(streamID: Int) async {
        guard let server = streamServer(), (try? await server.request(EPGStationStopStreamRequest(streamID: streamID))) != nil else {
            return
        }
        guard server === client else { return }
        store.ownStreamIDs.removeAll { $0 == streamID }
    }

    public func cleanUp() async {
        guard let server = streamServer() else { return }
        for id in store.ownStreamIDs {
            do { try await server.request(EPGStationStopStreamRequest(streamID: id)) } catch RegzaError.httpStatus(404) {} catch {
                continue
            }
            guard server === client else { return }
            store.ownStreamIDs.removeAll { $0 == id }
        }
    }

    /// cleanUp をメインスレッドを使わずに行う (アプリの終了時に、メインスレッドで待ちながら呼ぶ)
    public nonisolated static func cleanUp(_ server: EPGStationAPIClient, store: any RegzaConnectionStore) async {
        for id in store.ownStreamIDs {
            // 止める指示が届いたか、もう無い (404) ときだけ忘れる
            do {
                try await server.request(EPGStationStopStreamRequest(streamID: id))
                store.ownStreamIDs.removeAll { $0 == id }
            } catch RegzaError.httpStatus(404) {
                store.ownStreamIDs.removeAll { $0 == id }
            } catch {}
        }
    }

    public func stopStalled() async {
        guard let server = streamServer(), let streams = try? await server.request(EPGStationStreamsRequest()) else { return }
        guard server === client else { return }
        for stream in streams where !stream.isEnabled {
            try? await server.request(EPGStationStopStreamRequest(streamID: stream.id))
            guard server === client else { return }
            store.ownStreamIDs.removeAll { $0 == stream.id }
        }
    }
}
