import Foundation
import Observation

/// 番組表 (Mirakurun) と、番組を最初から見る (タイムシフトマシン) の ViewModel。アプリ全体で 1 つ (iOS と Android で共有)
@MainActor
@Observable
public final class GuideViewModel {
    public let remote: RemoteViewModel

    public init(remote: RemoteViewModel) {
        self.remote = remote
        guideHost = remote.store.guideHost
    }

    /// 開発用の見本データを出す
    public func showSample(guideHost: String, programs: [MirakurunProgram]) {
        self.guideHost = guideHost
        guidePrograms = Self.byChannel(programs)
        guideProgramsLoadedAt = .distantFuture
    }

    // MARK: - 番組表 (Mirakurun)

    /// Mirakurun のアドレス。未設定なら空
    public private(set) var guideHost: String
    public var hasGuide: Bool { !guideHost.isEmpty }
    @ObservationIgnored private var guide: Mirakurun?
    /// 全チャンネルの番組をチャンネルの ID ごとに時刻順で持つ (チャンネル一覧で今の番組を出す用)
    public private(set) var guidePrograms: [String: [MirakurunProgram]] = [:]
    /// 番組表を読み込んだ時刻 (検索の索引を作り直すかを決めるのに使う)
    public private(set) var guideProgramsLoadedAt: Date?

    public func saveGuideHost(_ host: String) async {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != guideHost else { return }
        guideHost = host
        guide = nil
        guidePrograms = [:]
        guideProgramsLoadedAt = nil
        await remote.updateGuide(host: host)
    }

    private func guideClient() -> Mirakurun? {
        guard hasGuide else { return nil }
        if let guide, guide.host == guideHost { return guide }
        let client = Mirakurun(host: guideHost)
        guide = client
        return client
    }

    /// 全チャンネルの番組を読む。数 MB あるので 30 分に 1 回まで
    public func loadGuidePrograms() async {
        guard let guide = guideClient() else { return }
        if let guideProgramsLoadedAt, Date().timeIntervalSince(guideProgramsLoadedAt) < 30 * 60 { return }
        guard let programs = try? await guide.allPrograms() else { return }
        guidePrograms = Self.byChannel(programs)
        guideProgramsLoadedAt = Date()
    }

    private static func byChannel(_ programs: [MirakurunProgram]) -> [String: [MirakurunProgram]] {
        Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
    }

    /// そのチャンネルでいま放送中の番組
    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guidePrograms[channel.code]?.first { $0.isOnAir(at: date) }
    }

    /// 1 チャンネルの番組表 (放送中の番組から)
    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        if remote.isSampleMode { return (guidePrograms[channel.code] ?? []).filter { $0.end > Date() } }
        guard let guide = guideClient() else { throw .notConfigured }
        do {
            let now = Date()
            return try await guide.programs(channelCode: channel.code).filter { $0.end > now }
        } catch {
            throw RegzaError(error)
        }
    }

    // MARK: - 最初から見る (タイムシフトマシン)

    /// 読み込んだ設定と、そのときの接続。接続が変わったら使わない
    private var loadedTimeshift: (settings: RegzaTimeshiftSettings, connection: RegzaConnection)?

    /// タイムシフトマシンの設定。録画している局と時間帯で「最初から見る」を出すか決める
    public var timeshiftSettings: RegzaTimeshiftSettings? {
        loadedTimeshift.flatMap { $0.connection == remote.connection ? $0.settings : nil }
    }

    public func loadTimeshiftSettings() async {
        guard !remote.isSampleMode, timeshiftSettings == nil else { return }
        let connection = remote.connection
        guard let settings = try? await remote.remote.client.timeshiftSettings() else { return }
        loadedTimeshift = (settings, connection)
    }

    /// その局の番組を最初から見られるか。録画していない番組で「始めにジャンプ」を押すとテレビにエラーが出るので、
    /// 対象の局で、番組の始まりから今までずっと録画している時間帯のときだけ true
    public func canStartOver(channelCode: String, programStart: Date) -> Bool {
        timeshiftSettings?.canStartOver(channelCode: channelCode, programStart: programStart) ?? false
    }

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    public func startOver() {
        remote.send(.press(.jumpToStart))
    }

    /// チャンネルを切り替えてから、その番組を最初から再生する
    public func tuneAndStartOver(_ channel: RegzaChannel) async throws(RegzaError) {
        try await remote.tune(to: channel)
        // 選局が落ち着くのを待ってから送る
        try? await Task.sleep(for: .seconds(3))
        remote.send(.press(.jumpToStart))
    }
}
