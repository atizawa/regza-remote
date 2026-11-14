/// 端末内に保存するアプリ設定。
/// @mockable
@MainActor
public protocol AppPreferencesRepositoryProtocol: AnyObject {
    var preferences: AppPreferencesData { get }
    func save(_ preferences: AppPreferencesData)
}
