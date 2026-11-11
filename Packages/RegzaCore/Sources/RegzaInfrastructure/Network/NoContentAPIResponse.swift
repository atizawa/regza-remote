/// HTTP の成功だけで完了する操作に共通の応答。
struct NoContentAPIResponse: APIResponse {
    let value: Void = ()
    init(_ output: Void) async throws {}
}
