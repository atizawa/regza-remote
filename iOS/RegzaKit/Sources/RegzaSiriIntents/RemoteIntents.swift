#if os(iOS)
import AppIntents
import Foundation
import RegzaApp
import RegzaAppContainer
import RegzaLiveActivity

// Siri・ショートカットから使う操作。画面と同じ ViewModel (RegzaAppContainer) に操作を送り、終わるのを待って結果を返す。
// アプリのプロセスの ViewModel を使うので、アプリにだけ登録する (ウィジェットの拡張機能には登録しない)。
// 呼びかけの言い方 (AppShortcutsProvider) はアプリのターゲットにある

// MARK: - チャンネル

/// テレビに登録されているチャンネル
public struct ChannelEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "チャンネル"
    public static let defaultQuery = ChannelQuery()

    /// チャンネル一覧の `ChannelItem.code`
    public let id: String
    public let name: String
    public let number: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(number)")
    }

    init(_ channel: ChannelItem) {
        id = channel.code
        name = channel.name
        number = channel.numberText
    }
}

public struct ChannelQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [ChannelEntity] {
        let channels = try await Self.channels()
        return identifiers.compactMap { id in channels.first { $0.code == id }.map(ChannelEntity.init) }
    }

    /// 候補として出すのは放送局ごとの代表チャンネル (サブチャンネルを除く)
    public func suggestedEntities() async throws -> [ChannelEntity] {
        try await Self.channels().filter { $0.isRepresentative || $0.band == .cs }.map(ChannelEntity.init)
    }

    /// 「NHK」のように半角で言っても、全角の局名 (ＮＨＫ総合) に合うようにする
    public func entities(matching string: String) async throws -> [ChannelEntity] {
        let query = Self.normalize(string)
        guard !query.isEmpty else { return [] }
        let channels = try await Self.channels()
        let matched = channels.filter { Self.normalize($0.name).contains(query) || $0.numberText == query }
        // 同じ局のサブチャンネルより代表チャンネルを先にする
        return matched.sorted { $0.isRepresentative && !$1.isRepresentative }.map(ChannelEntity.init)
    }

    static func normalize(_ text: String) -> String {
        (text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text)
            .lowercased()
            .filter { !$0.isWhitespace && $0 != "・" && $0 != "･" }
    }

    /// テレビに登録されているチャンネル。まだ読んでいなければ読む
    @MainActor
    static func channels() async throws -> [ChannelItem] {
        let remote = RegzaAppContainer.shared.app.remote
        guard remote.state.isConfigured else { throw RegzaError.notConfigured }
        await remote.sendAndWait(.loadChannels(force: false))
        guard !remote.registeredChannels.isEmpty else {
            throw RegzaError.network(remote.state.errorMessage ?? "チャンネル一覧を取得できませんでした")
        }
        return remote.registeredChannels
    }
}

/// チャンネルを切り替える
public struct TuneChannelIntent: AppIntent {
    public static let title: LocalizedStringResource = "テレビのチャンネルを切り替える"
    public static let description = IntentDescription("REGZA を指定したチャンネルに切り替えます。")

    @Parameter(title: "チャンネル")
    public var channel: ChannelEntity

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("テレビを\(\.$channel)に切り替える")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let channels = try await ChannelQuery.channels()
        guard let target = channels.first(where: { $0.code == channel.id }) else {
            throw RegzaError.commandRejected("チャンネルが見つかりません")
        }
        // チャンネル一覧の画面と同じ選局 (切り替えられなければ tuneError に説明が入る)
        let container = RegzaAppContainer.shared
        let channelList = container.app.channelList
        await channelList.sendAndWait(.tune(target.code))
        if let error = channelList.state.tuneError { throw RegzaError.commandRejected(error) }
        await container.liveActivity.update()
        return .result(dialog: "\(target.name)に切り替えました")
    }
}

// MARK: - ボタン

/// Siri・ショートカットから送れるボタン
public enum RemoteCommand: String, AppEnum {
    case power, volumeUp, volumeDown, mute, channelUp, channelDown, input
    case play, pause, stop, skipForward, skipBackward, recordedList

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "操作"

    public static let caseDisplayRepresentations: [RemoteCommand: DisplayRepresentation] = [
        .power: DisplayRepresentation(title: "電源", synonyms: ["電源ボタン", "テレビの電源"]),
        .volumeUp: DisplayRepresentation(title: "音量を上げる", synonyms: ["音量アップ", "音を大きく"]),
        .volumeDown: DisplayRepresentation(title: "音量を下げる", synonyms: ["音量ダウン", "音を小さく"]),
        .mute: DisplayRepresentation(title: "消音", synonyms: ["ミュート", "音を消す"]),
        .channelUp: DisplayRepresentation(title: "次のチャンネル", synonyms: ["チャンネルアップ"]),
        .channelDown: DisplayRepresentation(title: "前のチャンネル", synonyms: ["チャンネルダウン"]),
        .input: DisplayRepresentation(title: "入力切替", synonyms: ["入力を切り替える"]),
        .play: DisplayRepresentation(title: "再生", synonyms: ["再生する"]),
        .pause: DisplayRepresentation(title: "一時停止", synonyms: ["止める", "ポーズ"]),
        .stop: DisplayRepresentation(title: "停止", synonyms: ["再生を止める"]),
        .skipForward: DisplayRepresentation(title: "30秒送り", synonyms: ["スキップ"]),
        .skipBackward: DisplayRepresentation(title: "10秒戻し", synonyms: ["少し戻す"]),
        .recordedList: DisplayRepresentation(title: "録画リスト", synonyms: ["録画一覧"]),
    ]

    var key: RegzaKey {
        switch self {
        case .power: .power
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case .mute: .mute
        case .channelUp: .channelUp
        case .channelDown: .channelDown
        case .input: .input
        case .play: .play
        case .pause: .pause
        case .stop: .stop
        case .skipForward: .skipForward
        case .skipBackward: .skipBackward
        case .recordedList: .recordedList
        }
    }
}

/// リモコンのボタンを 1 つ送る
public struct RemoteCommandIntent: AppIntent {
    public static let title: LocalizedStringResource = "テレビを操作する"
    public static let description = IntentDescription("REGZA のリモコンのボタンを押します。")

    @Parameter(title: "操作")
    public var command: RemoteCommand

    /// 音量のように続けて押したい操作のための回数
    @Parameter(title: "回数", default: 1, inclusiveRange: (1, 10))
    public var count: Int

    public init() {}

    public init(_ command: RemoteCommand) {
        self.command = command
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("テレビの\(\.$command)を\(\.$count)回押す")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = RegzaAppContainer.shared
        let remote = container.app.remote
        guard remote.state.isConfigured else { throw RegzaError.notConfigured }
        let key = command.key
        for _ in 0..<max(1, count) {
            // リモコンの画面と同じ操作 (送ったあと、テレビの状態を取り直す)。送れなければ errorMessage に説明が入る
            await remote.sendAndWait(.press(key))
            if let error = remote.state.errorMessage { throw RegzaError.commandRejected(error) }
        }
        await container.liveActivity.update()
        return .result(dialog: "\(key.label)を送りました")
    }
}

/// アプリの AppIntentsPackage から参照して、このモジュールの Intent を登録する (ウィジェットの拡張機能には登録しない)
public struct RegzaSiriIntents: AppIntentsPackage {}
#endif
