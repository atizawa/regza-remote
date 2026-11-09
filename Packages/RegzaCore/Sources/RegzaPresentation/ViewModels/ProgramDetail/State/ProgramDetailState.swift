public import Foundation

/// 番組の詳細の画面の状態 (ProgramDetailViewModel.State)
public struct ProgramDetailState: Equatable, Sendable {
    public var program: ProgramItem
    /// 番組内容・出演者など
    public var texts: [ProgramTextItem]
    public var channelCode: String
    public var channelName: String
    public var isTuning: Bool
    public var reserving: ProgramDetailReserving?
    /// 予約・取り消しが終わった回数 (触覚フィードバックの合図)
    public var reserveCount: Int
    /// 画面に出す説明。予約の説明を優先する
    public var message: String?
    /// 予約済みの説明 (「連ドラ予約済み（毎週）」など)。予約していなければ nil
    public var reservedText: String?
    /// 予約が連ドラ予約か。予約していなければ nil
    public var reservationIsSeries: Bool?
    /// 放送中なら切り替えられる
    public var canTune: Bool
    /// 終わっていなければ予約できる
    public var canReserve: Bool
    /// アプリで見られる
    public var canStream: Bool
    public var canStartOver: Bool

    public var isReserved: Bool { reservationIsSeries != nil }
}
