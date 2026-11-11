import Foundation

/// テレビ (REGZA) の操作: リモコンのキー・選局・いま映っているもの・チャンネル・接続の保存
@MainActor
public protocol TVUseCaseProtocol: AnyObject {
    /// 保存してある接続
    var connection: ConnectionItem { get }

    /// テレビに登録されているチャンネル。取得前は空
    var channels: [ChannelItem] { get }

    /// 見本 (テレビにつながない)
    var isSample: Bool { get }

    func loadChannels(force: Bool) async throws(RegzaError)

    func send(_ key: RegzaKey) async throws(RegzaError)

    /// 選局する。切り替わったものとしての「いま映っているもの」を返す
    func tune(to channel: ChannelItem) async throws(RegzaError) -> NowPlayingItem?

    func seek(to seconds: Int) async throws(RegzaError)

    func refresh() async throws(RegzaError) -> NowPlayingItem

    func lastNowPlaying() async -> NowPlayingItem?

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかれば新しい接続を保存して返す
    func locateMovedTV() async -> ConnectionItem?

    func loadTimeshiftSettings() async

    /// その局の番組を最初から見られるか (タイムシフトマシンで、番組の始まりから録画している時間帯)
    func canStartOver(channelCode: String, programStart: Date) -> Bool

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    func startOver() async throws(RegzaError)

    /// チャンネルを切り替えてから、その番組を最初から再生する。
    /// 切り替えた直後は「始めにジャンプ」が効かないので、選局が落ち着くのを待ってから送る
    func tuneAndStartOver(_ channel: ChannelItem) async throws(RegzaError) -> NowPlayingItem?

    func save(_ connection: ConnectionItem) async

    /// 保存前の接続で、いま映っているものを取ってみる
    func testConnection(_ connection: ConnectionItem) async -> Result<NowPlayingItem, RegzaError>

    /// PIN 登録に使うこのアプリ用のユーザー ID
    func pairingUserID() -> String
}

extension TVUseCaseProtocol {
    public func loadChannels() async throws(RegzaError) {
        try await loadChannels(force: false)
    }
}

/// テレビ (REGZA) の操作: リモコンのキー・選局・いま映っているもの・チャンネル・接続の保存
@MainActor
public final class TVUseCase: TVUseCaseProtocol {
    private let tvRepository: any TVRepositoryProtocol

    public init(tvRepository: any TVRepositoryProtocol) {
        self.tvRepository = tvRepository
    }

    /// 保存してある接続
    public var connection: ConnectionItem { UseCaseModelMapper.connection(tvRepository.connection) }
    /// テレビに登録されているチャンネル。取得前は空
    public var channels: [ChannelItem] { tvRepository.channels.map(UseCaseModelMapper.channel) }
    /// 見本 (テレビにつながない)
    public var isSample: Bool { tvRepository.isSample }

    public func loadChannels(force: Bool = false) async throws(RegzaError) {
        try await tvRepository.loadChannels(force: force)
    }

    public func send(_ key: RegzaKey) async throws(RegzaError) {
        try await tvRepository.send(key)
    }

    /// 選局する。切り替わったものとしての「いま映っているもの」を返す
    public func tune(to channel: ChannelItem) async throws(RegzaError) -> NowPlayingItem? {
        guard let data = tvRepository.channels.first(where: { $0.code == channel.code }) else { throw .unsupported }
        return try await tvRepository.tune(to: data).map(UseCaseModelMapper.nowPlaying)
    }

    public func seek(to seconds: Int) async throws(RegzaError) {
        try await tvRepository.seek(to: seconds)
    }

    public func refresh() async throws(RegzaError) -> NowPlayingItem {
        UseCaseModelMapper.nowPlaying(try await tvRepository.refresh())
    }

    public func lastNowPlaying() async -> NowPlayingItem? {
        await tvRepository.lastNowPlaying().map(UseCaseModelMapper.nowPlaying)
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかれば新しい接続を保存して返す
    public func locateMovedTV() async -> ConnectionItem? {
        await tvRepository.locateMovedTV().map(UseCaseModelMapper.connection)
    }

    func item(_ data: NowPlayingData) -> NowPlayingItem {
        UseCaseModelMapper.nowPlaying(data)
    }

    // MARK: - 最初から見る (タイムシフトマシン)

    public func loadTimeshiftSettings() async {
        await tvRepository.loadTimeshiftSettings()
    }

    /// その局の番組を最初から見られるか (タイムシフトマシンで、番組の始まりから録画している時間帯)
    public func canStartOver(channelCode: String, programStart: Date) -> Bool {
        tvRepository.canStartOver(channelCode: channelCode, programStart: programStart)
    }

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    public func startOver() async throws(RegzaError) {
        try await tvRepository.send(.jumpToStart)
    }

    /// チャンネルを切り替えてから、その番組を最初から再生する。
    /// 切り替えた直後は「始めにジャンプ」が効かないので、選局が落ち着くのを待ってから送る
    public func tuneAndStartOver(_ channel: ChannelItem) async throws(RegzaError) -> NowPlayingItem? {
        guard let data = tvRepository.channels.first(where: { $0.code == channel.code }) else { throw .unsupported }
        let nowPlaying = try await tvRepository.tune(to: data)
        try? await Task.sleep(for: .seconds(3))
        try? await tvRepository.send(.jumpToStart)
        return nowPlaying.map(UseCaseModelMapper.nowPlaying)
    }

    // MARK: - 接続の設定

    public func save(_ connection: ConnectionItem) async {
        await tvRepository.save(UseCaseModelMapper.connectionData(connection))
    }

    /// 保存前の接続で、いま映っているものを取ってみる
    public func testConnection(_ connection: ConnectionItem) async -> Result<NowPlayingItem, RegzaError> {
        await tvRepository.testConnection(UseCaseModelMapper.connectionData(connection)).map(UseCaseModelMapper.nowPlaying)
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    public func pairingUserID() -> String {
        tvRepository.pairingUserID()
    }
}
