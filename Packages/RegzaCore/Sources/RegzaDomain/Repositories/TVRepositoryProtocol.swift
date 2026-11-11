import Foundation

/// テレビ (REGZA) とのやり取り。接続・チャンネル・タイムシフトマシンの設定は、読み込んだものを持っておく
@MainActor
public protocol TVRepositoryProtocol: AnyObject {
    /// 保存してある接続
    var connection: ConnectionData { get }
    /// テレビに登録されているチャンネル (読み込んだもの)。取得前は空
    var channels: [ChannelData] { get }
    /// タイムシフトマシンの設定 (読み込んだもの)。録画している局と時間帯で「最初から見る」を出すか決める
    var timeshiftSettings: TimeshiftSettingsData? { get }
    /// 見本 (テレビにつながない)
    var isSample: Bool { get }

    /// チャンネル一覧を読む。`force` でなければ、読み込み済みのものを使い回す
    func loadChannels(force: Bool) async throws(RegzaError)
    func loadTimeshiftSettings() async
    func send(_ key: RegzaKey) async throws(RegzaError)
    /// 選局する。切り替わったものとしての「いま映っているもの」を返す (切り替えの最中はテレビに問い合わせない)
    func tune(to channel: ChannelData) async throws(RegzaError) -> NowPlayingData?
    /// 録画の再生位置を移す (秒)
    func seek(to seconds: Int) async throws(RegzaError)
    /// いま映っているものをテレビから取り直す
    func refresh() async throws(RegzaError) -> NowPlayingData
    /// 最後に取れた「いま映っているもの」(選局のあとは、切り替わったものとしてのもの)
    func lastNowPlaying() async -> NowPlayingData?
    /// DHCP などで IP アドレスが変わったテレビを探す。見つかれば、新しいアドレスの接続を保存して返す
    func locateMovedTV() async -> ConnectionData?
    /// 接続を保存して、読み込んだものを捨てる
    func save(_ connection: ConnectionData) async
    /// 保存前の接続で、いま映っているものを取ってみる
    func testConnection(_ connection: ConnectionData) async -> Result<NowPlayingData, RegzaError>
    /// PIN 登録に使うこのアプリ用のユーザー ID
    func pairingUserID() -> String
}

extension TVRepositoryProtocol {
    /// その局の番組を最初から見られるか。録画していない番組で「始めにジャンプ」を押すとテレビにエラーが出るので、
    /// 対象の局で、番組の始まりから今までずっと録画している時間帯のときだけ true
    public func canStartOver(channelCode: String, programStart: Date) -> Bool {
        timeshiftSettings?.canStartOver(channelCode: channelCode, programStart: programStart) ?? false
    }
}
