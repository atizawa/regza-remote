public import Foundation

/// 設定の最初の画面に出すテレビの状態。操作できるときはアドレスだけ、注意が要るときだけ目立たせる
public struct TVSetupStatus: Equatable, Sendable {
    public var text: String
    public var needsAttention: Bool
}
