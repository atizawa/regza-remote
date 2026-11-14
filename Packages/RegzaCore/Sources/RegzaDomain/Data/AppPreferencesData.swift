/// 保存するアプリ設定。未知の保存値の扱いはUseCaseが決める。
public struct AppPreferencesData: Equatable, Sendable {
    public var appearance: String

    public init(appearance: String = "system") { self.appearance = appearance }
}
