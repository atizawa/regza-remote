#if os(iOS)
import AppIntents
import RegzaApp

/// Live Activity / Dynamic Island のボタンから REGZA にキーを送る。
/// LiveActivityIntent なのでアプリのプロセスで実行される。
public struct RegzaKeyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "REGZAのボタンを押す"
    public static let isDiscoverable = false

    @Parameter(title: "キー")
    public var keyName: String

    public init() {}

    public init(_ key: RegzaKey) {
        keyName = key.rawValue
    }

    public func perform() async throws -> some IntentResult {
        if let key = RegzaKey(rawValue: keyName) {
            try await RegzaRemoteService.send(key)
            // チャンネルを変えると番組の終了時刻も変わるので、起こしてもらう時刻を予約し直す
            await BackgroundRefresh.schedule()
        }
        return .result()
    }
}

/// アプリ・ウィジェット側の AppIntentsPackage から参照して、このモジュールの Intent を登録する
public struct RegzaLiveActivityIntents: AppIntentsPackage {}
#endif
