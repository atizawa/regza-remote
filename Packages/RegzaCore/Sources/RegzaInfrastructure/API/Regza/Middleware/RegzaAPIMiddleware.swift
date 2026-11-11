import Foundation
import HTTPTypes
import OpenAPIRuntime
import RegzaDomain

/// nonce の状態はクライアントごとに持つ。接続情報を変えたときは新しいインスタンスへ交換する。
actor RegzaDigestMiddleware: ClientMiddleware {
    private let connection: RegzaConnection
    private var challenge: DigestChallenge?
    private var nonceCount = 0

    init(connection: RegzaConnection) { self.connection = connection }

    func intercept(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        // 単一消費の HTTPBody でも、再試行では同じフォームを送り直す。
        let data: Data?
        if let body { data = try await Data(collecting: body, upTo: .max) } else { data = nil }
        let url = try OpenAPIHTTPTransport.url(for: request, baseURL: baseURL)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw RegzaError.invalidHost }
        let uri = components.percentEncodedPath + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
        try Task.checkCancellation()
        let response = try await next(authorize(request, uri: uri), data.map { HTTPBody($0) }, baseURL)
        guard response.0.status.code == 401 else { return response }
        guard let header = response.0.headerFields[.wwwAuthenticate], let newChallenge = DigestChallenge(header: header) else {
            throw RegzaError.unauthorized
        }
        let retry = challenge == nil || challenge != newChallenge
        challenge = newChallenge
        nonceCount = 0
        guard retry else { throw RegzaError.unauthorized }
        try Task.checkCancellation()
        return try await next(authorize(request, uri: uri), data.map { HTTPBody($0) }, baseURL)
    }

    private func authorize(_ request: HTTPTypes.HTTPRequest, uri: String) -> HTTPTypes.HTTPRequest {
        guard let challenge else { return request }
        var request = request
        nonceCount += 1
        request.headerFields[.authorization] = challenge.authorization(
            method: request.method.rawValue, uri: uri, user: connection.user, password: connection.password,
            nonceCount: nonceCount, clientNonce: (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        )
        return request
    }
}

/// 機種の差を生成コードの外で吸収する。旧 API の本文はバイト列のままにする。
struct RegzaCompatibilityMiddleware: ClientMiddleware {
    var queryOverride: String?

    func intercept(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        var request = request
        if let queryOverride, let path = request.path { request.path = path + "?" + queryOverride }
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

/// 認証の再試行が終わった後の HTTP エラーを、従来の公開エラーへ変換する。
struct RegzaResponseMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        let response = try await next(request, body, baseURL)
        switch response.0.status.code {
        case 200..<300: return response
        case 401: throw RegzaError.unauthorized
        default: throw RegzaError.httpStatus(response.0.status.code)
        }
    }
}
