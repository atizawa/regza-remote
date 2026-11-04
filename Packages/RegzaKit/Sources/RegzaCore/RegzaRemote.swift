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
    /// 放送中の番組名を補う番組表。未設定なら nil
    public private(set) var guide: Mirakurun?
    /// 番組名を毎回問い合わせないよう、直前に調べた番組を覚えておく (取れなかったときは 1 分後に調べ直す)
    private var lastProgram: (id: Int, program: MirakurunProgram?, checkedAt: Date)?

    public init(connection: RegzaConnection, guide: Mirakurun? = nil) {
        client = RegzaClient(connection: connection)
        self.guide = guide
    }

    public func update(guide: Mirakurun?) {
        self.guide = guide
        lastProgram = nil
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

    public func tune(to channel: RegzaChannel) async throws {
        try await client.tune(to: channel.code)
        lastCommand = nil
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
                let status = try await client.playStatus()
                supportsPlayStatus = true
                updated = await withProgramName(RegzaNowPlaying(playStatus: status), status: status)
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

    /// テレビが放送中の番組名を返さない機種向けに、番組表から番組名と説明を補う
    private func withProgramName(_ nowPlaying: RegzaNowPlaying, status: RegzaPlayStatus) async -> RegzaNowPlaying {
        guard nowPlaying.kind == .broadcast, nowPlaying.title.isEmpty, let guide,
              let id = status.currentProgram?.epgContentID.flatMap(Mirakurun.programID(epgContentID:))
        else { return nowPlaying }
        let program: MirakurunProgram?
        if let lastProgram, lastProgram.id == id,
           lastProgram.program != nil || Date().timeIntervalSince(lastProgram.checkedAt) < 60 {
            program = lastProgram.program
        } else {
            // 番組表が取れなくても視聴状況はそのまま返す
            program = try? await guide.program(id: id)
            lastProgram = (id, program, Date())
        }
        guard let program else { return nowPlaying }
        var result = nowPlaying
        result.title = program.name
        if result.description.isEmpty {
            result.description = program.description
        }
        return result
    }

    private func legacyStatus() async throws -> RegzaNowPlaying {
        RegzaNowPlaying(status: try await client.status(), previous: nowPlaying)
    }
}
