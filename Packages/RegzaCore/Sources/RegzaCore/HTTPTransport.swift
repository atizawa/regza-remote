import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// テレビや録画サーバーへの HTTP の問い合わせ
public struct HTTPRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    /// 返事が途切れてから諦めるまでの秒数
    public var timeout: TimeInterval

    public init(method: String = "GET", url: URL, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    /// 名前は小文字にそろえてある
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        self.body = body
    }

    public func value(forHTTPHeaderField name: String) -> String? {
        headers[name.lowercased()]
    }
}

/// HTTP の送り方。iOS は URLSession、Android は自前のソケット (Android の URLSession は返事を待つ間 CPU を使い続けるため)。
/// 失敗は `RegzaError.network` で返す
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum RegzaHTTP {
    /// RegzaCore の通信が使う送り方。Android はテレビとやり取りする前に差し替える
    nonisolated(unsafe) public static var transport: any HTTPTransport = URLSessionTransport()
}

/// URLSession で送る
public final class URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: LocalTrustDelegate(), delegateQueue: nil)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let running = RunningTask()
        // FoundationNetworking では async の data(for:) が使えない場合があるので completion 版を使う
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: urlRequest) { data, response, error in
                    if let error {
                        continuation.resume(throwing: RegzaError.network(error.localizedDescription))
                    } else if let response = response as? HTTPURLResponse {
                        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, field in
                            if let name = field.key as? String, let value = field.value as? String { result[name] = value }
                        }
                        continuation.resume(returning: HTTPResponse(statusCode: response.statusCode, headers: headers, body: data ?? Data()))
                    } else {
                        continuation.resume(throwing: RegzaError.network("不正なレスポンスです"))
                    }
                }
                running.start(task)
            }
        } onCancel: {
            running.cancel()
        }
    }

    /// 取り消しが始まる前に来ても後に来ても、通信を止められるようにする
    private final class RunningTask: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var isCancelled = false

        func start(_ task: URLSessionDataTask) {
            lock.lock()
            self.task = task
            let cancelled = isCancelled
            lock.unlock()
            task.resume()
            if cancelled { task.cancel() }
        }

        func cancel() {
            lock.lock()
            isCancelled = true
            let task = task
            lock.unlock()
            task?.cancel()
        }
    }
}

/// テレビの HTTPS は自己署名の証明書なので、テレビの HTTPS のポートへの接続に限って証明書を受け入れる。
/// 同じ内容は HTTP (80 番) でも平文で送っているので、受け入れても安全性は下がらない
private final class LocalTrustDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        #if canImport(Security)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           challenge.protectionSpace.port == RegzaClient.securePort,
           let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        #endif
        return (.performDefaultHandling, nil)
    }
}
