import AppErrors
import Foundation
import RegzaApp

/// Kotlin が実装する通信の窓口。開始と取消は MainActor 上で呼び、送受信自体は OkHttp に任せる。
public protocol RegzaAndroidHTTPClient {
    func start(_ request: RegzaAndroidHTTPRequest, completion: RegzaAndroidHTTPCompletion)
    func cancel(_ id: String)
}

/// JNI で扱える値だけを持つ。ヘッダーは名前・値の順、本文は文字列へ変換しない。
public final class RegzaAndroidHTTPRequest {
    public let id: String
    public let address: String
    public let method: String
    public let headers: [String]
    public let body: [Int8]
    public let hasBody: Bool
    public let timeout: Double
    public let verifiesCertificate: Bool

    init(_ request: HTTPRequest) {
        id = UUID().uuidString
        address = request.url.absoluteString
        method = request.method
        headers = request.headers.sorted { $0.key < $1.key }.flatMap { [$0.key, $0.value] }
        body = request.body.map { data in data.withUnsafeBytes { Array($0.bindMemory(to: Int8.self)) } } ?? []
        hasBody = request.body != nil
        timeout = request.timeout
        verifiesCertificate = request.url.scheme != "https" || request.url.port != RegzaAPIClient.securePort
    }
}

/// OkHttp の完了通知を Swift の await へ返す。取消や遅れて届く完了が重なっても 1 回だけ再開する。
public final class RegzaAndroidHTTPCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<HTTPResponse, RegzaError>?
    private var continuation: CheckedContinuation<HTTPResponse, any Error>?

    public func succeed(_ status: Int32, _ headers: [String], _ body: [Int8]) {
        guard (100...599).contains(status), headers.count.isMultiple(of: 2) else {
            finish(.failure(.connection(.invalidResponse)))
            return
        }
        let fields = stride(from: 0, to: headers.count, by: 2).reduce(into: [String: String]()) { fields, index in
            fields[headers[index]] = headers[index + 1]
        }
        let data = body.withUnsafeBytes { Data($0) }
        finish(.success(HTTPResponse(statusCode: Int(status), headers: fields, body: data)))
    }

    // 失敗は種類だけを受け取る。文言は共有の Swift が決める (OS の例外の文は、言語が違い、接続先のアドレスが入ることもあるので使わない)

    /// 接続先が見つからない・つながらない
    public func failCannotConnect() { finish(.failure(.connection(.cannotConnect))) }
    /// 決めた時間までに返事がない
    public func failTimedOut() { finish(.failure(.connection(.timedOut))) }
    /// 接続先の証明書を確かめられない
    public func failCertificate() { finish(.failure(.connection(.certificate))) }
    /// 通信を取り消した
    public func failCancelled() { finish(.failure(.connection(.cancelled))) }
    /// そのほかの理由で返事を受け取れない
    public func fail() { finish(.failure(.connection(.other))) }

    var isFinished: Bool { lock.withLock { result != nil } }

    func wait(_ continuation: CheckedContinuation<HTTPResponse, any Error>) {
        let result: Result<HTTPResponse, RegzaError>? = lock.withLock {
            if let result = self.result { return result }
            self.continuation = continuation
            return nil
        }
        if let result { continuation.resume(with: result.mapError { $0 as any Error }) }
    }

    private func finish(_ result: Result<HTTPResponse, RegzaError>) {
        let continuation = lock.withLock {
            guard self.result == nil else { return nil as CheckedContinuation<HTTPResponse, any Error>? }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        continuation?.resume(with: result.mapError { $0 as any Error })
    }
}

/// 共通コアの HTTPTransport を Android の通信実装へ接続する。HTTP の解釈・TLS・DNS は行わない。
final class AndroidHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let httpClient: any RegzaAndroidHTTPClient

    init(httpClient: any RegzaAndroidHTTPClient) {
        self.httpClient = httpClient
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let outgoing = RegzaAndroidHTTPRequest(request)
        let completion = RegzaAndroidHTTPCompletion()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion.wait(continuation)
                Task { @MainActor in
                    guard !completion.isFinished else { return }
                    self.httpClient.start(outgoing, completion: completion)
                }
            }
        } onCancel: {
            completion.failCancelled()
            Task { @MainActor in self.httpClient.cancel(outgoing.id) }
        }
    }
}
