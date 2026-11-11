import Foundation

/// 接続情報の永続化。プラットフォームごとに実装する
/// (iOS はキーチェーン、Android は SharedPreferences など)。
public protocol RegzaConnectionStore: Sendable {
    func load() -> ConnectionData
    func save(_ connection: ConnectionData)
    /// PIN 登録に使うこのアプリ用のユーザー ID。無ければ作って保存する。
    /// 入れ直しても同じ ID になるよう、アプリを削除しても消えない場所に保存する
    /// (同じ ID で登録し直すとテレビ側で上書きされ、登録が増えない)
    func pairingUserID() -> String
    /// 番組表を読む Mirakurun のアドレス。未設定なら空
    var guideHost: String { get nonmutating set }
    /// iPhone で番組を見るための EPGStation のアドレス。未設定なら空
    var streamHost: String { get nonmutating set }
    /// このアプリが EPGStation に頼んで、まだ止めていない配信の番号 (StreamViewModel)
    var ownStreamIDs: [Int] { get nonmutating set }
}
