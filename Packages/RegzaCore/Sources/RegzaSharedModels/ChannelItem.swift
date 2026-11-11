import Foundation

/// チャンネル一覧の 1 局 (UI で使う形)。ChannelUseCase が Domain の ChannelData から作る
public struct ChannelItem: Equatable, Sendable, Identifiable {
    /// チャンネルの ID (`JP-G…`)。選局などの操作は、これで送る
    public var code: String
    public var name: String
    /// 「011」「BS181」など、一覧の左に出す番号
    public var numberText: String
    /// 放送中の番組名
    public var programName: String?
    /// いま映っている
    public var isNowPlaying: Bool
    /// 番組表を開ける
    public var hasPrograms: Bool
    /// 放送中の番組を最初から見られる
    public var canStartOver: Bool
    /// 控えめに出す (同じ放送局のサブチャンネル。CS は局ごとに別なので控えめにしない)
    public var isSubchannel: Bool
    public var band: BroadcastBand
    public var isRepresentative: Bool
    public var remoteNumber: Int
    public var id: String { code }

    public init(
        code: String, name: String, numberText: String, programName: String?, isNowPlaying: Bool,
        hasPrograms: Bool, canStartOver: Bool, isSubchannel: Bool,
        band: BroadcastBand = .other, isRepresentative: Bool = true, remoteNumber: Int = 0
    ) {
        self.code = code
        self.name = name
        self.numberText = numberText
        self.programName = programName
        self.isNowPlaying = isNowPlaying
        self.hasPrograms = hasPrograms
        self.canStartOver = canStartOver
        self.isSubchannel = isSubchannel
        self.band = band
        self.isRepresentative = isRepresentative
        self.remoteNumber = remoteNumber
    }
}
