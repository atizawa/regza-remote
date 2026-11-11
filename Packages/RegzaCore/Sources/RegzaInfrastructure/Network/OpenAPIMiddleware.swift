import Foundation
import HTTPTypes
import OpenAPIRuntime
import RegzaDomain

/// JSON 内の生の制御文字と、サーバーが省略した Content-Type を補う。テキスト・映像は補正しない。
struct OpenAPIJSONMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        var (response, body) = try await next(request, body, baseURL)
        guard (200..<300).contains(response.status.code) else { return (response, body) }
        let expectsJSON = request.headerFields[.accept]?.contains("application/json") == true
        if response.headerFields[.contentType] == nil {
            response.headerFields[.contentType] = expectsJSON ? "application/json" : "text/plain"
        }
        if expectsJSON, let received = body {
            let data = try await Data(collecting: received, upTo: .max)
            body = HTTPBody(LenientJSON.escapingControlCharactersInStrings(data))
            response.headerFields[.contentLength] = nil
        }
        return (response, body)
    }
}

/// HTTP エラーをアプリ共通のエラーに変換する。Digest の再試行より外側に置く。
struct OpenAPIResponseMiddleware: ClientMiddleware {
    var usesDigestAuthentication = false

    func intercept(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        let response = try await next(request, body, baseURL)
        switch response.0.status.code {
        case 200..<300: return response
        case 401 where usesDigestAuthentication: throw RegzaError.unauthorized
        default: throw RegzaError.httpStatus(response.0.status.code)
        }
    }
}

func performOpenAPI<Value>(
    _ operation: () async throws -> Value, isolation: isolated (any Actor)? = #isolation
) async throws -> Value {
    do { return try await operation() } catch let error as ClientError {
        if let underlying = error.underlyingError as? RegzaError { throw underlying }
        if error.underlyingError is CancellationError { throw CancellationError() }
        throw RegzaError.unsupported
    }
}

/// サーバーの仕様の basePath (/api) と、利用者が設定したホスト・ポートを組み合わせる。
func recordingServerURL(host: String, defaultPort: Int, template: URL) throws -> URL {
    guard !host.isEmpty else { throw RegzaError.notConfigured }
    let address = host.contains("://") ? host : "http://" + host
    guard var components = URLComponents(string: address), components.host != nil,
        components.scheme == "http" || components.scheme == "https"
    else { throw RegzaError.invalidHost }
    if components.port == nil { components.port = defaultPort }
    components.path = template.path
    components.query = nil
    components.fragment = nil
    guard let url = components.url else { throw RegzaError.invalidHost }
    return url
}
