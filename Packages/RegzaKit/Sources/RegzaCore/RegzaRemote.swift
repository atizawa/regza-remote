import Foundation

/// リモコン操作と再生状況の追跡をまとめたもの。
/// UI フレームワークに依存しないので、iOS は SwiftUI / App Intents から、
/// Android は JNI 経由で同じものを使う。
public actor RegzaRemote {
    public let client: RegzaClient
    public private(set) var nowPlaying: RegzaNowPlaying?
    public private(set) var lastCommand: RegzaKey?
    /// v2 API (`play/status`) に対応しているか。未確認なら nil
    private var supportsPlayStatus: Bool?

    public init(connection: RegzaConnection) {
        client = RegzaClient(connection: connection)
    }

    public func update(connection: RegzaConnection) async {
        await client.update(connection: connection)
        nowPlaying = nil
        supportsPlayStatus = nil
    }

    public func send(_ key: RegzaKey) async throws {
        try await client.send(key)
        lastCommand = key
    }

    public func seek(to seconds: Int) async throws {
        try await client.seek(to: seconds)
    }

    /// 視聴状況を取得して更新する。
    /// v2 API を優先し、未対応の機種では旧 API (`status.htm`) を使う
    @discardableResult
    public func refresh() async throws -> RegzaNowPlaying {
        let updated: RegzaNowPlaying
        if supportsPlayStatus != false {
            do {
                updated = RegzaNowPlaying(playStatus: try await client.playStatus())
                supportsPlayStatus = true
            } catch RegzaError.httpStatus(404), RegzaError.unsupported {
                supportsPlayStatus = false
                updated = try await legacyStatus()
            }
        } else {
            updated = try await legacyStatus()
        }
        nowPlaying = updated
        return updated
    }

    private func legacyStatus() async throws -> RegzaNowPlaying {
        RegzaNowPlaying(status: try await client.status(), previous: nowPlaying)
    }
}
