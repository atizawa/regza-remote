import Foundation
import HTTPTypes
import OpenAPIRuntime
import RegzaDomain

/// 生成クライアントと既存の HTTPTransport の間で、問い合わせ・応答の型を変換する。
struct OpenAPIHTTPTransport: ClientTransport {
    var transport: any HTTPTransport
    var timeout: TimeInterval

    func send(
        _ request: HTTPTypes.HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
    ) async throws -> (HTTPTypes.HTTPResponse, HTTPBody?) {
        let url = try Self.url(for: request, baseURL: baseURL)
        let data: Data?
        if let body { data = try await Data(collecting: body, upTo: .max) } else { data = nil }
        let headers = Dictionary(request.headerFields.map { ($0.name.rawName, $0.value) }, uniquingKeysWith: { _, last in last })
        let response = try await transport.send(
            HTTPRequest(
                method: request.method.rawValue, url: url, headers: headers, body: data, timeout: timeout
            ))
        var fields = HTTPFields()
        for (name, value) in response.headers {
            if let name = HTTPField.Name(name) { fields.append(.init(name: name, value: value)) }
        }
        return (.init(status: .init(code: response.statusCode), headerFields: fields), HTTPBody(response.body))
    }

    static func url(for request: HTTPTypes.HTTPRequest, baseURL: URL) throws -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let path = request.path, path.hasPrefix("/"), let url = URL(string: base + path) else {
            throw RegzaError.invalidHost
        }
        return url
    }
}
