#if os(iOS)
import Foundation
import RegzaCore

/// このアプリが EPGStation に頼んだ配信の番号を覚えておく。
/// EPGStation は配信を自動では止めないので、アプリが強制終了されて止められなかった配信は、次に開いたときに止める
enum LiveStreams {
    private static let key = "epgstation.ownStreams"

    static var ids: [Int] {
        get { UserDefaults.standard.array(forKey: key) as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func started(_ id: Int) {
        if !ids.contains(id) { ids.append(id) }
    }

    static func stopped(_ id: Int) {
        ids.removeAll { $0 == id }
    }

    /// 止められずに残った、このアプリの配信を止める
    static func cleanUp(_ server: EPGStation) async {
        for id in ids {
            // 止める指示が届いたか、もう無い (404) ときだけ忘れる
            do {
                try await server.stop(streamID: id)
                stopped(id)
            } catch RegzaError.httpStatus(404) {
                stopped(id)
            } catch {}
        }
    }

    /// 準備できないまま残っている配信 (ほかの端末のものも含む) を止める。利用者が選んだときだけ使う
    static func stopStalled(_ server: EPGStation) async {
        guard let streams = try? await server.streams() else { return }
        for stream in streams where !stream.isEnabled {
            try? await server.stop(streamID: stream.id)
            stopped(stream.id)
        }
    }
}
#endif
