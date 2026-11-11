import Foundation
import Observation
import RegzaDomain

/// ライブ配信 (StreamRepositoryProtocol の実装)。録画サーバー EPGStation に頼む。
/// このアプリが頼んだ配信の番号は保存先に覚え、アプリが強制終了されて止められなかった配信は、次に開いたときに止める
@MainActor
@Observable
public final class EPGStationStreamRepository: StreamRepositoryProtocol {
    @ObservationIgnored private let preferencesManager: PreferencesManager
    @ObservationIgnored private var epgStationAPIClient: EPGStationAPIClient

    public private(set) var streamHost: String

    public init(preferencesManager: PreferencesManager, epgStationAPIClient: EPGStationAPIClient) {
        self.preferencesManager = preferencesManager
        self.epgStationAPIClient = epgStationAPIClient
        streamHost = epgStationAPIClient.host
    }

    /// この Repository の配信先が設定されている。番組表との組み合わせは UseCase が判断する。
    public var canStream: Bool { !streamHost.isEmpty }

    public func saveStreamHost(_ host: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        preferencesManager.setValue(host, forKey: .streamHost)
        streamHost = host
        epgStationAPIClient = epgStationAPIClient.replacingHost(host)
    }

    /// 配信を頼む EPGStation。配信できないなら nil
    public func streamServer() -> EPGStationAPIClient? {
        canStream ? epgStationAPIClient : nil
    }

    public func isPlayable(channelCode: String) -> Bool {
        BroadcastID.ids(channelCode: channelCode) != nil
    }

    public func startLiveStream(channelCode: String) async throws(RegzaError) -> Int {
        guard let serverAPIClient = streamServer() else { throw .notConfigured }
        guard let ids = BroadcastID.ids(channelCode: channelCode) else { throw .unsupported }
        let channelID = ids.networkId * 100_000 + ids.serviceId
        let streamID: Int
        do {
            streamID = try await serverAPIClient.request(EPGStationStartStreamRequest(channelID: channelID, mode: 0))
        } catch {
            throw RegzaError(error)
        }
        guard serverAPIClient === epgStationAPIClient else {
            try? await serverAPIClient.request(EPGStationStopStreamRequest(streamID: streamID))
            throw .notConfigured
        }
        preferencesManager.updateIntegers(forKey: .ownStreamIDs) { if !$0.contains(streamID) { $0.append(streamID) } }
        return streamID
    }

    public func waitUntilReady(streamID: Int) async throws(RegzaError) -> URL {
        guard let serverAPIClient = streamServer() else { throw .notConfigured }
        do {
            try await EPGStationStreaming(epgStationAPIClient: serverAPIClient).waitUntilReady(streamID: streamID)
        } catch {
            throw RegzaError(error)
        }
        guard serverAPIClient === epgStationAPIClient else { throw .notConfigured }
        guard let url = EPGStationStreaming(epgStationAPIClient: serverAPIClient).playlistURL(streamID: streamID) else {
            throw .invalidHost
        }
        return url
    }

    public func keep(streamID: Int) async {
        try? await streamServer()?.request(EPGStationKeepStreamRequest(streamID: streamID))
    }

    public func stop(streamID: Int) async {
        guard let serverAPIClient = streamServer(),
            (try? await serverAPIClient.request(EPGStationStopStreamRequest(streamID: streamID))) != nil
        else {
            return
        }
        guard serverAPIClient === epgStationAPIClient else { return }
        preferencesManager.updateIntegers(forKey: .ownStreamIDs) { $0.removeAll { $0 == streamID } }
    }

    public func cleanUp() async {
        guard let serverAPIClient = streamServer() else { return }
        for id in preferencesManager.integers(forKey: .ownStreamIDs) {
            do { try await serverAPIClient.request(EPGStationStopStreamRequest(streamID: id)) } catch RegzaError.httpStatus(404) {} catch {
                continue
            }
            guard serverAPIClient === epgStationAPIClient else { return }
            preferencesManager.updateIntegers(forKey: .ownStreamIDs) { $0.removeAll { $0 == id } }
        }
    }

    /// cleanUp をメインスレッドを使わずに行う (アプリの終了時に、メインスレッドで待ちながら呼ぶ)
    public nonisolated static func cleanUp(_ epgStationAPIClient: EPGStationAPIClient, preferencesManager: PreferencesManager) async {
        for id in preferencesManager.integers(forKey: .ownStreamIDs) {
            // 止める指示が届いたか、もう無い (404) ときだけ忘れる
            do {
                try await epgStationAPIClient.request(EPGStationStopStreamRequest(streamID: id))
                preferencesManager.updateIntegers(forKey: .ownStreamIDs) { $0.removeAll { $0 == id } }
            } catch RegzaError.httpStatus(404) {
                preferencesManager.updateIntegers(forKey: .ownStreamIDs) { $0.removeAll { $0 == id } }
            } catch {}
        }
    }

    public func stopStalled() async {
        guard let serverAPIClient = streamServer(), let streams = try? await serverAPIClient.request(EPGStationStreamsRequest()) else {
            return
        }
        guard serverAPIClient === epgStationAPIClient else { return }
        for stream in streams where !stream.isEnabled {
            try? await serverAPIClient.request(EPGStationStopStreamRequest(streamID: stream.id))
            guard serverAPIClient === epgStationAPIClient else { return }
            preferencesManager.updateIntegers(forKey: .ownStreamIDs) { $0.removeAll { $0 == stream.id } }
        }
    }
}
