/// OpenAPI の型付き操作と、その応答の変換を結び付ける。
protocol APIRequest: Sendable {
    associatedtype Client: Sendable
    associatedtype Response: APIResponse

    func send(using client: Client) async throws -> Response.Output
}

func executeAPIRequest<Request: APIRequest>(
    _ request: Request, using client: Request.Client, isolation: isolated (any Actor)? = #isolation
) async throws -> Request.Response.Value {
    try await performOpenAPI {
        let output = try await request.send(using: client)
        return try await Request.Response(output).value
    }
}
