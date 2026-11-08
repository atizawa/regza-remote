import Foundation
import Observation
import RegzaDomain

/// ライブ配信 (StreamRepositoryProtocol の実装)。録画サーバー EPGStation に頼む。
/// このアプリが頼んだ配信の番号は保存先に覚え、アプリが強制終了されて止められなかった配信は、次に開いたときに止める
@MainActor
@Observable
public final class EPGStationStreamRepository: StreamRepositoryProtocol {
    @ObservationIgnored private let store: any RegzaConnectionStore
    @ObservationIgnored private let guide: any GuideRepositoryProtocol
    @ObservationIgnored private let transport: any HTTPTransport

    public private(set) var streamHost: String

    public init(store: any RegzaConnectionStore, guide: any GuideRepositoryProtocol, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.store = store
        self.guide = guide
        self.transport = transport
        streamHost = store.streamHost
    }

    /// EPGStation だけでは番組名も出ず、見られない局も一覧に混ざるので、Mirakurun も設定しているときだけ使う
    public var canStream: Bool { !streamHost.isEmpty && guide.hasGuide }

    public func saveStreamHost(_ host: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        store.streamHost = host
        streamHost = host
    }

    /// 配信を頼む EPGStation。配信できないなら nil
    public func streamServer() -> EPGStation? {
        canStream ? EPGStation(host: streamHost, transport: transport) : nil
    }

    public func isPlayable(channelCode: String) -> Bool {
        EPGStation.channelID(channelCode: channelCode) != nil
    }

    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        guard let server = streamServer() else { throw .notConfigured }
        guard let channelID = EPGStation.channelID(channelCode: channelCode) else { throw .unsupported }
        let streamID: Int
        do {
            streamID = try await server.startLiveStream(channelID: channelID)
        } catch {
            throw RegzaError(error)
        }
        if !store.ownStreamIDs.contains(streamID) { store.ownStreamIDs.append(streamID) }
        return streamID
    }

    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL {
        guard let server = streamServer() else { throw .notConfigured }
        do {
            try await server.waitUntilReady(streamID: streamID)
        } catch {
            throw RegzaError(error)
        }
        guard let url = server.playlistURL(streamID: streamID) else { throw .invalidHost }
        return url
    }

    public func keep(streamID: Int) async {
        try? await streamServer()?.keep(streamID: streamID)
    }

    public func stop(streamID: Int) async {
        guard let server = streamServer(), (try? await server.stop(streamID: streamID)) != nil else { return }
        store.ownStreamIDs.removeAll { $0 == streamID }
    }

    public func cleanUp() async {
        guard let server = streamServer() else { return }
        await Self.cleanUp(server, store: store)
    }

    /// cleanUp をメインスレッドを使わずに行う (アプリの終了時に、メインスレッドで待ちながら呼ぶ)
    public nonisolated static func cleanUp(_ server: EPGStation, store: any RegzaConnectionStore) async {
        for id in store.ownStreamIDs {
            // 止める指示が届いたか、もう無い (404) ときだけ忘れる
            do {
                try await server.stop(streamID: id)
                store.ownStreamIDs.removeAll { $0 == id }
            } catch RegzaError.httpStatus(404) {
                store.ownStreamIDs.removeAll { $0 == id }
            } catch {}
        }
    }

    public func stopStalled() async {
        guard let server = streamServer(), let streams = try? await server.streams() else { return }
        for stream in streams where !stream.isEnabled {
            try? await server.stop(streamID: stream.id)
            store.ownStreamIDs.removeAll { $0 == stream.id }
        }
    }
}
