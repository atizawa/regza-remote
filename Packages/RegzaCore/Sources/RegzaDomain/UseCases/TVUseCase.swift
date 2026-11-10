import Foundation

/// テレビ (REGZA) の操作: リモコンのキー・選局・いま映っているもの・チャンネル・接続の保存
@MainActor
public protocol TVUseCaseProtocol: AnyObject {
    /// 保存してある接続
    var connection: RegzaConnection { get }

    /// テレビに登録されているチャンネル。取得前は空
    var channels: [RegzaChannel] { get }

    /// 見本 (テレビにつながない)
    var isSample: Bool { get }

    func loadChannels(force: Bool) async throws(RegzaError)

    func send(_ key: RegzaKey) async throws(RegzaError)

    /// 選局する。切り替わったものとしての「いま映っているもの」を返す
    func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying?

    func seek(to seconds: Int) async throws(RegzaError)

    func refresh() async throws(RegzaError) -> RegzaNowPlaying

    func lastNowPlaying() async -> RegzaNowPlaying?

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかれば新しい接続を保存して返す
    func locateMovedTV() async -> RegzaConnection?

    /// いま映っているもの (UI の型)。画面に出す文言は Domain の RegzaNowPlaying の決まりで作る
    func item(_ nowPlaying: RegzaNowPlaying) -> NowPlayingItem

    func loadTimeshiftSettings() async

    /// その局の番組を最初から見られるか (タイムシフトマシンで、番組の始まりから録画している時間帯)
    func canStartOver(channelCode: String, programStart: Date) -> Bool

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    func startOver() async throws(RegzaError)

    /// チャンネルを切り替えてから、その番組を最初から再生する。
    /// 切り替えた直後は「始めにジャンプ」が効かないので、選局が落ち着くのを待ってから送る
    func tuneAndStartOver(_ channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying?

    func save(_ connection: RegzaConnection) async

    /// 保存前の接続で、いま映っているものを取ってみる
    func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError>

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
    private let tv: any TVRepositoryProtocol

    public init(tv: any TVRepositoryProtocol) {
        self.tv = tv
    }

    /// 保存してある接続
    public var connection: RegzaConnection { tv.connection }
    /// テレビに登録されているチャンネル。取得前は空
    public var channels: [RegzaChannel] { tv.channels }
    /// 見本 (テレビにつながない)
    public var isSample: Bool { tv.isSample }

    public func loadChannels(force: Bool = false) async throws(RegzaError) {
        try await tv.loadChannels(force: force)
    }

    public func send(_ key: RegzaKey) async throws(RegzaError) {
        try await tv.send(key)
    }

    /// 選局する。切り替わったものとしての「いま映っているもの」を返す
    public func tune(to channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        try await tv.tune(to: channel)
    }

    public func seek(to seconds: Int) async throws(RegzaError) {
        try await tv.seek(to: seconds)
    }

    public func refresh() async throws(RegzaError) -> RegzaNowPlaying {
        try await tv.refresh()
    }

    public func lastNowPlaying() async -> RegzaNowPlaying? {
        await tv.lastNowPlaying()
    }

    /// DHCP などで IP アドレスが変わったテレビを探し、見つかれば新しい接続を保存して返す
    public func locateMovedTV() async -> RegzaConnection? {
        await tv.locateMovedTV()
    }

    /// いま映っているもの (UI の型)。画面に出す文言は Domain の RegzaNowPlaying の決まりで作る
    public func item(_ nowPlaying: RegzaNowPlaying) -> NowPlayingItem {
        NowPlayingItem(
            kind: NowPlayingKind(rawValue: nowPlaying.kind.rawValue) ?? .unknown,
            channelName: nowPlaying.channelName,
            channelCode: nowPlaying.channelCode,
            title: nowPlaying.title,
            description: nowPlaying.description,
            chapterName: nowPlaying.chapterName,
            genre: nowPlaying.genre,
            position: nowPlaying.position,
            duration: nowPlaying.duration,
            isAdvancing: nowPlaying.isAdvancing,
            updatedAt: nowPlaying.updatedAt,
            nextProgramStart: nowPlaying.nextProgramStart,
            nextProgramDuration: nowPlaying.nextProgramDuration,
            nextTitle: nowPlaying.nextTitle,
            shortChannel: nowPlaying.shortChannel,
            captionText: nowPlaying.captionText,
            headlineText: nowPlaying.headlineText,
            statusText: nowPlaying.statusText
        )
    }

    // MARK: - 最初から見る (タイムシフトマシン)

    public func loadTimeshiftSettings() async {
        await tv.loadTimeshiftSettings()
    }

    /// その局の番組を最初から見られるか (タイムシフトマシンで、番組の始まりから録画している時間帯)
    public func canStartOver(channelCode: String, programStart: Date) -> Bool {
        tv.canStartOver(channelCode: channelCode, programStart: programStart)
    }

    /// いま映っている番組を最初から再生する (リモコンの「始めにジャンプ」)
    public func startOver() async throws(RegzaError) {
        try await tv.send(.jumpToStart)
    }

    /// チャンネルを切り替えてから、その番組を最初から再生する。
    /// 切り替えた直後は「始めにジャンプ」が効かないので、選局が落ち着くのを待ってから送る
    public func tuneAndStartOver(_ channel: RegzaChannel) async throws(RegzaError) -> RegzaNowPlaying? {
        let nowPlaying = try await tv.tune(to: channel)
        try? await Task.sleep(for: .seconds(3))
        try? await tv.send(.jumpToStart)
        return nowPlaying
    }

    // MARK: - 接続の設定

    public func save(_ connection: RegzaConnection) async {
        await tv.save(connection)
    }

    /// 保存前の接続で、いま映っているものを取ってみる
    public func testConnection(_ connection: RegzaConnection) async -> Result<RegzaNowPlaying, RegzaError> {
        await tv.testConnection(connection)
    }

    /// PIN 登録に使うこのアプリ用のユーザー ID
    public func pairingUserID() -> String {
        tv.pairingUserID()
    }
}
