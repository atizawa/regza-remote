#if os(iOS)
import AppIntents
import RegzaCore

/// Live Activity / Dynamic Island のボタンから REGZA にキーを送る。
/// LiveActivityIntent なのでアプリのプロセスで実行される。
public struct RegzaKeyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "REGZAのボタンを押す"
    public static let isDiscoverable = false

    @Parameter(title: "キーコード")
    public var keyCode: String

    public init() {}

    public init(_ key: RegzaKey) {
        keyCode = key.rawValue
    }

    public func perform() async throws -> some IntentResult {
        if let key = RegzaKey(rawValue: keyCode) {
            try await RegzaRemoteService.send(key)
        }
        return .result()
    }
}

/// アプリ・ウィジェット側の AppIntentsPackage から参照して、このモジュールの Intent を登録する
public struct RegzaLiveActivityIntents: AppIntentsPackage {}
#endif
