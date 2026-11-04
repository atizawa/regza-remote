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

    public init() {
        connection = RegzaRemoteService.store.load()
        isLiveActivityOn = LiveActivityController.isActive
    }

    // MARK: - リモコン

    public func send(_ key: RegzaKey) {
        tapCount += 1
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

    /// テレビに登録されているチャンネル。取得前は空
    public private(set) var channels: [RegzaChannel] = []

    /// チャンネル一覧を取得する。チャンネルの登録はあまり変わらないので、取得済みなら使い回す
    public func loadChannels(force: Bool = false) async throws(RegzaError) {
        guard force || channels.isEmpty else { return }
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

    // MARK: - 録画

    /// 録画予約。予定のあるものを先に、時刻順に並べる
    public private(set) var reservations: [RegzaReservation] = []

    public func loadReservations() async throws(RegzaError) {
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

    /// 番組表の番組を 1 回だけ録画予約する
    public func reserve(_ program: MirakurunProgram) async throws(RegzaError) {
        do {
            try await RegzaRemoteService.remote.client.reserve(
                channel: program.channelCode,
                epgContentID: program.epgContentID,
                start: program.start,
                duration: Int(program.end.timeIntervalSince(program.start))
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
        guard pollingTask == nil, connection.isConfigured else { return }
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
