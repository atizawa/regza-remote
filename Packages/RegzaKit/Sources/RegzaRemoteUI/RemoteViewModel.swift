#if os(iOS)
import Foundation
import Observation
import RegzaCore
import RegzaLiveActivity

@MainActor
@Observable
public final class RemoteViewModel {
    public private(set) var connection: RegzaConnection
    public private(set) var nowPlaying: RegzaNowPlaying?
    public private(set) var lastError: RegzaError?
    public private(set) var isLiveActivityOn: Bool
    /// ボタンを押したときの触覚フィードバック用
    public private(set) var tapCount = 0
    /// つながらないので、IP アドレスが変わっていないかテレビを探している
    public private(set) var isSearchingTV = false

    private var pollingTask: Task<Void, Never>?
    private var lastSearch: Date?
    /// テレビの電源が切れているだけのこともあるので、探し直す間隔を空ける
    private static let searchInterval: TimeInterval = 180

    /// 開発用の見本データを表示している (テレビにはつながない)
    private(set) var isSampleMode = false

    public init() {
        connection = RegzaRemoteService.store.load()
        isLiveActivityOn = LiveActivityController.isActive
        #if DEBUG
        if SampleData.isEnabled { loadSampleData() }
        #endif
    }

    #if DEBUG
    private func loadSampleData() {
        isSampleMode = true
        connection = RegzaConnection(host: "192.0.2.1")
        nowPlaying = SampleData.nowPlaying()
        channels = SampleData.channels()
        // -SampleNoGuide YES で Mirakurun が未設定のときの画面を確かめる
        guard !UserDefaults.standard.bool(forKey: "SampleNoGuide") else { return }
        let programs = SampleData.programs()
        guideHost = "192.0.2.2"
        guidePrograms = Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
        guideProgramsLoadedAt = .distantFuture
        reservations = SampleData.reservations(programs: programs)
    }
    #endif

    // MARK: - リモコン

    public func send(_ key: RegzaKey) {
        tapCount += 1
        guard !isSampleMode else { return }
        Task {
            do {
                try await RegzaRemoteService.send(key)
                lastError = nil
                nowPlaying = await RegzaRemoteService.remote.nowPlaying
            } catch let error as RegzaError {
                lastError = error
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }
    }

    public func seek(to seconds: Int) {
        Task {
            do {
                try await RegzaRemoteService.seek(to: seconds)
                nowPlaying = await RegzaRemoteService.remote.nowPlaying
            } catch let error as RegzaError {
                lastError = error
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }
    }

    // MARK: - チャンネル

    /// 番組表とチャンネル一覧で選んでいる放送の種類 (地デジ・BS・CS)。タブを行き来しても同じものを出す。未選択なら nil
    public var selectedBand: RegzaChannel.Band?

    /// 放送の種類を選んでいなければ、いま見ている放送の種類、それもなければ一覧の最初のものにする
    func band(among bands: [RegzaChannel.Band]) -> RegzaChannel.Band? {
        if let selectedBand, bands.contains(selectedBand) { return selectedBand }
        let current = channels.first { $0.code == nowPlaying?.channelCode }?.band
        if let current, bands.contains(current) { return current }
        return bands.first
    }

    /// テレビに登録されているチャンネル。取得前は空
    public private(set) var channels: [RegzaChannel] = []

    /// チャンネル一覧を取得する。チャンネルの登録はあまり変わらないので、取得済みなら使い回す
    public func loadChannels(force: Bool = false) async throws(RegzaError) {
        guard !isSampleMode, force || channels.isEmpty else { return }
        do {
            channels = try await RegzaRemoteService.remote.client.channels()
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
    }

    public func tune(to channel: RegzaChannel) async throws(RegzaError) {
        tapCount += 1
        do {
            try await RegzaRemoteService.tune(to: channel)
            lastError = nil
            nowPlaying = await RegzaRemoteService.remote.nowPlaying
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
    }

    // MARK: - 番組表 (Mirakurun)

    /// Mirakurun のアドレス。未設定なら空
    public private(set) var guideHost = RegzaRemoteService.store.guideHost
    public var hasGuide: Bool { !guideHost.isEmpty }
    private var guide: Mirakurun?
    /// 全チャンネルの番組をチャンネルの ID ごとに時刻順で持つ (チャンネル一覧で今の番組を出す用)
    public private(set) var guidePrograms: [String: [MirakurunProgram]] = [:]
    private var guideProgramsLoadedAt: Date?

    public func saveGuideHost(_ host: String) async {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard host != guideHost else { return }
        RegzaRemoteService.store.guideHost = host
        guideHost = host
        guide = nil
        guidePrograms = [:]
        guideProgramsLoadedAt = nil
        await RegzaRemoteService.reloadGuide()
        await refresh()
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
        guidePrograms = Dictionary(grouping: programs, by: \.channelCode).mapValues { $0.sorted { $0.start < $1.start } }
        guideProgramsLoadedAt = Date()
    }

    /// そのチャンネルでいま放送中の番組
    public func currentProgram(for channel: RegzaChannel, at date: Date = Date()) -> MirakurunProgram? {
        guidePrograms[channel.code]?.first { $0.isOnAir(at: date) }
    }

    /// 1 チャンネルの番組表 (放送中の番組から)
    public func programs(for channel: RegzaChannel) async throws(RegzaError) -> [MirakurunProgram] {
        if isSampleMode { return (guidePrograms[channel.code] ?? []).filter { $0.end > Date() } }
        guard let guide = guideClient() else { throw .notConfigured }
        do {
            let now = Date()
            return try await guide.programs(channelCode: channel.code).filter { $0.end > now }
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
    }

    // MARK: - ライブ視聴 (EPGStation)

    /// EPGStation のアドレス。未設定なら空
    public private(set) var streamHost = RegzaRemoteService.store.streamHost
    /// EPGStation は Mirakurun から放送を受け取るので、Mirakurun も設定しているときだけ使う
    /// (EPGStation だけでは番組名も出ず、見られない局も一覧に混ざる)
    public var canStream: Bool { !streamHost.isEmpty && hasGuide && !isSampleMode }

    public func saveStreamHost(_ host: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        RegzaRemoteService.store.streamHost = host
        streamHost = host
    }

    func streamServer() -> EPGStation? {
        canStream ? EPGStation(host: streamHost) : nil
    }

    /// いま映っている放送のチャンネル
    var nowPlayingChannel: RegzaChannel? {
        guard let code = nowPlaying?.channelCode, !code.isEmpty else { return nil }
        return channels.first { $0.code == code }
    }

    // MARK: - 最初から見る (タイムシフトマシン)

    /// タイムシフトマシンの設定。録画している局と時間帯で「最初から見る」を出すか決める
    public private(set) var timeshiftSettings: RegzaTimeshiftSettings?

    public func loadTimeshiftSettings() async {
        guard !isSampleMode, timeshiftSettings == nil else { return }
        timeshiftSettings = try? await RegzaRemoteService.remote.client.timeshiftSettings()
    }

    /// その局の番組を最初から見られるか。録画していない番組で「始めにジャンプ」を押すとテレビにエラーが出るので、
    /// 対象の局で、番組の始まりから今までずっと録画している時間帯のときだけ true
    public func canStartOver(channelCode: String, programStart: Date) -> Bool {
        timeshiftSettings?.canStartOver(channelCode: channelCode, programStart: programStart) ?? false
    }

    /// いま映っている放送を最初から見られるか
    public var canStartOverNowPlaying: Bool {
        guard let nowPlaying, nowPlaying.kind == .broadcast, nowPlaying.hasTimeline else { return false }
        let start = nowPlaying.updatedAt.addingTimeInterval(-TimeInterval(nowPlaying.position))
        return canStartOver(channelCode: nowPlaying.channelCode, programStart: start)
    }

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    public func startOver() {
        send(.jumpToStart)
    }

    /// チャンネルを切り替えてから、その番組を最初から再生する
    public func tuneAndStartOver(_ channel: RegzaChannel) async throws(RegzaError) {
        try await tune(to: channel)
        // 選局が落ち着くのを待ってから送る
        try? await Task.sleep(for: .seconds(3))
        send(.jumpToStart)
    }

    // MARK: - 録画

    /// 録画予約。予定のあるものを先に、時刻順に並べる
    public private(set) var reservations: [RegzaReservation] = []

    public func loadReservations() async throws(RegzaError) {
        guard !isSampleMode else { return }
        let list: [RegzaReservation]
        do {
            list = try await RegzaRemoteService.remote.client.reservations()
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
        let now = Date()
        reservations = list.sorted { lhs, rhs in
            let left = lhs.isScheduled(now: now), right = rhs.isScheduled(now: now)
            // 予定のあるものは近い順、次の回が未定のものは最後に録画した回が新しい順
            return left != right ? left : (left ? lhs.start < rhs.start : lhs.start > rhs.start)
        }
    }

    /// その番組の予約。なければ nil
    public func reservation(for program: MirakurunProgram) -> RegzaReservation? {
        reservations.first { $0.isReservation(of: program.epgContentID) }
    }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        reservation(for: program) != nil
    }

    /// 番組表の番組を録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    public func reserve(_ program: MirakurunProgram, series: Bool = false) async throws(RegzaError) {
        do {
            try await RegzaRemoteService.remote.client.reserve(
                channel: program.channelCode,
                epgContentID: program.epgContentID,
                start: program.start,
                duration: Int(program.end.timeIntervalSince(program.start)),
                series: series
            )
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
        try? await loadReservations()
    }

    public func cancel(_ reservation: RegzaReservation) async throws(RegzaError) {
        do {
            try await RegzaRemoteService.remote.client.cancelReservation(id: reservation.id)
        } catch let error as RegzaError {
            throw error
        } catch {
            throw .network(error.localizedDescription)
        }
        reservations.removeAll { $0.id == reservation.id }
        try? await loadReservations()
    }

    // MARK: - 状態の定期取得

    public func startPolling(interval: Duration = .seconds(2)) {
        guard pollingTask == nil, connection.isConfigured, !isSampleMode else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() async {
        switch await RegzaRemoteService.refresh() {
        case .success(let value):
            nowPlaying = value
            lastError = nil
            lastSearch = nil
        case .failure(let error):
            lastError = error
            if case .network = error { await searchForMovedTV() }
        }
        isLiveActivityOn = LiveActivityController.isActive
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかればそのアドレスに切り替える
    private func searchForMovedTV() async {
        if let lastSearch, Date().timeIntervalSince(lastSearch) < Self.searchInterval { return }
        lastSearch = Date()
        isSearchingTV = true
        defer { isSearchingTV = false }
        let original = connection
        guard let host = await RegzaDiscovery.locate(original),
              // 探している間に設定画面で接続先が変えられていたら、そちらを優先する
              !Task.isCancelled, connection == original
        else { return }
        var moved = original
        moved.host = host
        RegzaRemoteService.store.save(moved)
        connection = moved
        await RegzaRemoteService.reloadConnection()
        await refresh()
    }

    // MARK: - 設定

    public func save(_ connection: RegzaConnection) async {
        RegzaRemoteService.store.save(connection)
        self.connection = connection
        nowPlaying = nil
        channels = []
        reservations = []
        timeshiftSettings = nil
        lastSearch = nil
        await RegzaRemoteService.reloadConnection()
        stopPolling()
        startPolling()
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    public func pairingUserID() -> String {
        RegzaRemoteService.store.pairingUserID()
    }

    /// 保存前の接続情報で視聴状況を取得してみる (普段と同じく v2 API を優先し、無ければ旧 API)
    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        do {
            return .success(try await RegzaRemote(connection: connection).refresh())
        } catch let error as RegzaError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    // MARK: - Live Activity

    public func setLiveActivity(_ enabled: Bool) async {
        do {
            if enabled {
                try await LiveActivityController.start()
                await refresh()
            } else {
                await LiveActivityController.end()
            }
        } catch {
            lastError = .network("Live Activity を開始できませんでした: \(error.localizedDescription)")
        }
        isLiveActivityOn = LiveActivityController.isActive
        await BackgroundRefresh.schedule()
    }

    /// Live Activity が出ていれば、閉じている間に iOS に起こしてもらう時刻を予約する
    public func scheduleBackgroundRefresh() {
        Task { await BackgroundRefresh.schedule() }
    }
}
#endif
