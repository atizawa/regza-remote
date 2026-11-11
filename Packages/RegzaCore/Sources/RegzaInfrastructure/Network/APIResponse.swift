/// 生成コードの応答から、アプリが使う値を作る。
protocol APIResponse: Sendable {
    associatedtype Output: Sendable
    associatedtype Value: Sendable

    init(_ output: Output) async throws
    var value: Value { get }
}
