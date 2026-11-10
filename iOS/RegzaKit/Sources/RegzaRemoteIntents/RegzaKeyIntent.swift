#if os(iOS)
import AppIntents
import RegzaAppContainer
import RegzaPresentation

/// Live Activity / Dynamic Island・ホーム画面のウィジェット・コントロールセンターのボタンから REGZA にキーを送る。
/// LiveActivityIntent なのでアプリのプロセスで実行され、画面と同じ ViewModel (RegzaAppContainer) に操作を送る
public struct RegzaKeyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "REGZAのボタンを押す"
    public static let isDiscoverable = false

    @Parameter(title: "キー")
    public var keyName: String

    public init() {}

    public init(_ key: RegzaKey) {
        keyName = key.rawValue
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let key = RegzaKey(rawValue: keyName) else { return .result() }
        let container = RegzaAppContainer.shared
        await container.app.remote.sendAndWait(.press(key))
        // アプリがまた止められる前に、Live Activity に出し終える (選局で番組が変われば、起こしてもらう時刻も予約し直す)
        await container.liveActivity.update()
        return .result()
    }
}

/// アプリ・ウィジェット側の AppIntentsPackage から参照して、このモジュールの Intent を登録する
public struct RegzaRemoteIntents: AppIntentsPackage {}
#endif
