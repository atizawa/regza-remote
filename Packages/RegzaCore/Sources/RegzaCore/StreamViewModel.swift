import Foundation
import Observation

/// 録画サーバー EPGStation で放送を見るための ViewModel。アプリ全体で 1 つ (iOS と Android で共有)。
/// EPGStation は配信を自動では止めないので、このアプリが頼んだ配信を覚えておき、
/// アプリが強制終了されて止められなかった配信は、次に開いたときに止める
@MainActor
@Observable
public final class StreamViewModel {
    public let remote: RemoteViewModel
    public let guide: GuideViewModel

    public init(remote: RemoteViewModel, guide: GuideViewModel) {
        self.remote = remote
        self.guide = guide
        streamHost = remote.store.streamHost
    }

    /// EPGStation のアドレス。未設定なら空
    public private(set) var streamHost: String

    /// EPGStation は Mirakurun から放送を受け取るので、Mirakurun も設定しているときだけ使う
    /// (EPGStation だけでは番組名も出ず、見られない局も一覧に混ざる)
    public var canStream: Bool { !streamHost.isEmpty && guide.hasGuide && !remote.isSampleMode }

    public func saveStreamHost(_ host: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        remote.store.streamHost = host
        streamHost = host
    }

    public func streamServer() -> EPGStation? {
        canStream ? EPGStation(host: streamHost) : nil
    }

    // MARK: - このアプリが頼んだ配信

    public func started(_ id: Int) {
        if !remote.store.ownStreamIDs.contains(id) { remote.store.ownStreamIDs.append(id) }
    }

    public func stopped(_ id: Int) {
        remote.store.ownStreamIDs.removeAll { $0 == id }
    }

    /// 止められずに残った、このアプリの配信を止める
    public func cleanUp() async {
        guard let server = streamServer() else { return }
        await Self.cleanUp(server, store: remote.store)
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

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める。利用者が選んだときだけ使う
    public func stopStalled() async {
        guard let server = streamServer(), let streams = try? await server.streams() else { return }
        for stream in streams where !stream.isEnabled {
            try? await server.stop(streamID: stream.id)
            stopped(stream.id)
        }
    }
}
