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
    /// この時刻までは視聴状況を問い合わせない。
    /// 録画の再生を始めるときなど、テレビの映像が切り替わっている最中に `play/status` を問い合わせると、
    /// テレビが再起動する機種がある (決定キーの 0.4 秒後の問い合わせで再起動することを実機で確認)
    private var quietUntil: Date?
    /// 映像の切り替えが落ち着くまで待つ時間。危ない時間は測っていないので余裕を持たせている
    static let switchingQuietPeriod: TimeInterval = 6

    /// テレビ本体のリモコンで切り替えられたときも `play/status` が重ならないよう、ふだんは旧 API (`status.htm`) で見張る。
    /// 旧 API は切り替えの最中に 0.2 秒おきに問い合わせても再起動しないことを実機で確認している。
    /// 見張った値が変わったら切り替え中とみなして待ち、`play/status` は落ち着いているときに間隔を空けて問い合わせる
    private var lastProbe: Probe?
    private var lastPlayStatusAt: Date?
    /// 自分でキーを送った後など、すぐに `play/status` で取り直したい
    private var needsPlayStatus = false
    /// 落ち着いているときに `play/status` を問い合わせる間隔
    static let playStatusInterval: TimeInterval = 15

    /// 旧 API の値のうち、切り替わると変わるもの
    struct Probe: Equatable {
        var action: Int
        var channelCode: String
        var titleNumber: Int
        var titleName: String

        init(_ status: RegzaStatus) {
            action = status.action
            channelCode = status.channelCode
            titleNumber = status.titleNumber
            titleName = status.titleName
        }
    }

    /// 番組名を毎回問い合わせないよう、調べた番組を覚えておく (取れなかったときは 1 分後に調べ直す)
    private var programCache: [Int: (program: MirakurunProgram?, checkedAt: Date)] = [:]

    public init(connection: RegzaConnection, guide: Mirakurun? = nil) {
        client = RegzaClient(connection: connection)
        self.guide = guide
    }

    public func update(guide: Mirakurun?) {
        self.guide = guide
        programCache = [:]
    }

    public func update(connection: RegzaConnection) async {
        await client.update(connection: connection)
        nowPlaying = nil
        supportsPlayStatus = nil
        lastProbe = nil
        lastPlayStatusAt = nil
    }

    public func send(_ key: RegzaKey) async throws {
        try await client.send(key)
        lastCommand = key
        needsPlayStatus = true
        if key.mayStartContentSwitch {
            quietUntil = Date().addingTimeInterval(Self.switchingQuietPeriod)
        }
    }

    public func tune(to channel: RegzaChannel) async throws {
        try await client.tune(to: channel.code)
        lastCommand = nil
        needsPlayStatus = true
    }

    public func seek(to seconds: Int) async throws {
        try await client.seek(to: seconds)
    }

    /// 視聴状況を取得して更新する。
    /// v2 API を優先し、未対応の機種では旧 API (`status.htm`) を使う
    /// 映像が切り替わるキーを送った直後は、落ち着くまで待ってから問い合わせる
    @discardableResult
    public func refresh() async throws -> RegzaNowPlaying {
        if let quietUntil {
            let wait = quietUntil.timeIntervalSinceNow
            if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
            self.quietUntil = nil
        }
        // v2 API で一度取れてからは、旧 API で見張って play/status を必要なときだけにする
        guard supportsPlayStatus == true, let current = nowPlaying else { return try await fetch() }

        let status = try await client.status()
        let probe = Probe(status)
        let previous = lastProbe
        lastProbe = probe
        if let previous, previous != probe {
            // 切り替わりの最中かもしれないので、落ち着くまで play/status は問い合わせない
            quietUntil = Date().addingTimeInterval(Self.switchingQuietPeriod)
            needsPlayStatus = true
            return current
        }
        let isDue = lastPlayStatusAt.map { Date().timeIntervalSince($0) >= Self.playStatusInterval } ?? true
        if needsPlayStatus || isDue {
            return try await fetch()
        }
        let updated = Self.advanced(current, with: status)
        nowPlaying = updated
        return updated
    }

    /// play/status を問い合わせない間は、前回の値を今の時刻まで進める (録画は旧 API の再生位置を使う)
    static func advanced(_ nowPlaying: RegzaNowPlaying, with status: RegzaStatus, now: Date = Date()) -> RegzaNowPlaying {
        var updated = nowPlaying
        switch nowPlaying.kind {
        case .recorded where status.isPlayingRecording:
            updated.isAdvancing = status.titleTime != nowPlaying.position
            updated.position = status.titleTime
            updated.chapterName = status.chapterName
        case .broadcast where nowPlaying.isAdvancing:
            let elapsed = Int(now.timeIntervalSince(nowPlaying.updatedAt))
            updated.position = min(nowPlaying.duration, nowPlaying.position + max(0, elapsed))
        default:
            return nowPlaying
        }
        updated.updatedAt = now
        return updated
    }

    /// 視聴状況を取り直す。v2 API を優先し、未対応の機種では旧 API (`status.htm`) を使う
    private func fetch() async throws -> RegzaNowPlaying {
        let updated: RegzaNowPlaying
        if supportsPlayStatus != false {
            do {
                let status = try await client.playStatus()
                supportsPlayStatus = true
                lastPlayStatusAt = Date()
                needsPlayStatus = false
                updated = await withProgramName(RegzaNowPlaying(playStatus: status), status: status)
            } catch let error as RegzaError where error == .httpStatus(404) || error == .unsupported {
                // 一度でも v2 API で取れたテレビなら、切り替え中などの一時的な失敗として扱い、旧 API に切り替えない
                guard supportsPlayStatus == nil else { throw error }
                supportsPlayStatus = false
                updated = try await legacyStatus()
            }
        } else {
            updated = try await legacyStatus()
        }
        nowPlaying = updated
        return updated
    }

    /// テレビが放送中の番組名を返さない機種向けに、番組表から番組名と説明を補う (次の番組名も)
    private func withProgramName(_ nowPlaying: RegzaNowPlaying, status: RegzaPlayStatus) async -> RegzaNowPlaying {
        guard nowPlaying.kind == .broadcast else { return nowPlaying }
        var result = nowPlaying
        if result.title.isEmpty, let program = await program(epgContentID: status.currentProgram?.epgContentID) {
            result.title = program.name
            if result.description.isEmpty {
                result.description = program.description
            }
        }
        if let next = status.nextProgram {
            if let title = next.title.map(RegzaNowPlaying.cleanTitle(_:)), !title.isEmpty {
                result.nextTitle = title
            } else if let program = await program(epgContentID: next.epgContentID) {
                result.nextTitle = program.name
            }
        }
        return result
    }

    private func program(epgContentID: String?) async -> MirakurunProgram? {
        guard let guide, let id = epgContentID.flatMap(Mirakurun.programID(epgContentID:)) else { return nil }
        if let cached = programCache[id], cached.program != nil || Date().timeIntervalSince(cached.checkedAt) < 60 {
            return cached.program
        }
        // 番組表が取れなくても視聴状況はそのまま返す
        let program = try? await guide.program(id: id)
        // 今と次の番組だけ覚えておけば足りるので、増えすぎたら捨てる
        if programCache.count > 8 { programCache = [:] }
        programCache[id] = (program, Date())
        return program
    }

    private func legacyStatus() async throws -> RegzaNowPlaying {
        RegzaNowPlaying(status: try await client.status(), previous: nowPlaying)
    }
}
