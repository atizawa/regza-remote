import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RegzaError: Error, Equatable, Sendable {
    case notConfigured
    case invalidHost
    case unauthorized
    case httpStatus(Int)
    /// remote.htm が 0 以外を返した
    case commandRejected(String)
    /// 機種が API に対応していない
    case unsupported
    /// PIN 登録で PIN が違う
    case invalidPIN
    case network(String)
}

extension RegzaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured: "接続先が設定されていません"
        case .invalidHost: "IPアドレスが正しくありません"
        case .unauthorized: "認証に失敗しました。ユーザー名とパスワードを確認してください"
        case .httpStatus(let code): "HTTPエラー (\(code))"
        case .commandRejected(let code): "テレビがコマンドを拒否しました (\(code))"
        case .unsupported: "この機種は対応していません"
        case .invalidPIN: "PIN が正しくありません。テレビに表示されている数字を確認してください"
        case .network(let message): message
        }
    }
}

/// REGZA の HTTP リモコン API クライアント。
///
/// - `GET /remote/remote.htm?key=XXXXXX` キー送信 (成功で `0`)
/// - `GET /remote/status.htm` 再生状況
/// - `GET /remote/ts.htm?SEC` シーク
///
/// いずれも Digest 認証が必要。PIN 登録は `RegzaPairing` を使う。
public actor RegzaClient {
    public private(set) var connection: RegzaConnection
    private let session: URLSession
    private var challenge: DigestChallenge?
    private var nonceCount = 0

    public init(connection: RegzaConnection, timeout: TimeInterval = 3) {
        self.connection = connection
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        // 接続テストや探し直しで作ったクライアントのセッションが残り続けないようにする
        session.finishTasksAndInvalidate()
    }

    public func update(connection: RegzaConnection) {
        guard connection != self.connection else { return }
        self.connection = connection
        challenge = nil
        nonceCount = 0
    }

    public func send(_ key: RegzaKey) async throws {
        let body = try await get(path: "/remote/remote.htm", query: "key=\(key.rawValue)")
        let result = body.trimmingCharacters(in: .whitespacesAndNewlines)
        // 0 以外 (1, 2) はエラー。数値以外が返る機種は成功扱いにする
        if let code = Int(result), code != 0 {
            throw RegzaError.commandRejected(result)
        }
    }

    public func status() async throws -> RegzaStatus {
        RegzaStatus(text: try await get(path: "/remote/status.htm", query: nil))
    }

    /// v2 API の視聴状態。放送中のチャンネルや番組の時刻も取れる。
    /// 未対応の機種では `RegzaError.httpStatus(404)` か `RegzaError.unsupported` になる
    public func playStatus() async throws -> RegzaPlayStatus {
        let data = try await getData(path: "/v2/remote/play/status", query: nil)
        guard let status = try? JSONDecoder().decode(RegzaPlayStatus.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard status.status == 0 else { throw RegzaError.commandRejected(String(status.status)) }
        return status
    }

    /// テレビに登録されているチャンネル。未対応の機種では `RegzaError.httpStatus(404)` か `RegzaError.unsupported` になる
    public func channels() async throws -> [RegzaChannel] {
        let data = try await getData(path: "/v2/remote/settings/channel_list", query: nil)
        guard let list = try? JSONDecoder().decode(RegzaChannelList.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        return list.channels ?? []
    }

    /// 録画予約の一覧
    public func reservations() async throws -> [RegzaReservation] {
        let data = try await getData(path: "/v2/remote/pvr/reserves/list", query: nil)
        guard let list = try? JSONDecoder().decode(RegzaReservationList.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        return list.reservations ?? []
    }

    /// チャンネル一覧の `code` で選局する (`POST /v2/remote/status/channel`)
    public func tune(to code: String) async throws {
        let data = try await post(path: "/v2/remote/status/channel", form: ["channel": code])
        guard let result = try? JSONDecoder().decode(RegzaResult.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard result.status == 0 else { throw RegzaError.commandRejected(String(result.status)) }
    }

    /// 録画再生中に指定秒数の位置へ移動する
    public func seek(to seconds: Int) async throws {
        _ = try await get(path: "/remote/ts.htm", query: String(max(0, seconds)))
    }

    // MARK: - HTTP

    private func get(path: String, query: String?) async throws -> String {
        Self.decode(try await getData(path: path, query: query))
    }

    /// フォームを POST する。資格情報があれば Digest 認証を付ける
    func post(path: String, form: [String: String]) async throws -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = form.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        return try await request(method: "POST", path: path, query: nil, body: Data(body.utf8))
    }

    private func getData(path: String, query: String?) async throws -> Data {
        try await request(method: "GET", path: path, query: query, body: nil)
    }

    private func request(method: String, path: String, query: String?, body: Data?) async throws -> Data {
        guard connection.isConfigured else { throw RegzaError.notConfigured }
        guard let url = makeURL(path: path, query: query) else { throw RegzaError.invalidHost }
        let uri = query.map { "\(path)?\($0)" } ?? path

        var (data, response) = try await perform(method: method, url: url, uri: uri, body: body)
        if response.statusCode == 401 {
            // nonce の期限切れなどで再チャレンジされたら、新しいチャレンジで 1 回だけやり直す
            guard let header = response.value(forHTTPHeaderField: "WWW-Authenticate"),
                  let newChallenge = DigestChallenge(header: header)
            else { throw RegzaError.unauthorized }
            let retry = challenge == nil || challenge != newChallenge
            challenge = newChallenge
            nonceCount = 0
            guard retry else { throw RegzaError.unauthorized }
            (data, response) = try await perform(method: method, url: url, uri: uri, body: body)
        }

        switch response.statusCode {
        case 200..<300: return data
        case 401: throw RegzaError.unauthorized
        default: throw RegzaError.httpStatus(response.statusCode)
        }
    }

    private func perform(method: String, url: URL, uri: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        if let challenge {
            nonceCount += 1
            request.setValue(
                challenge.authorization(
                    method: method, uri: uri,
                    user: connection.user, password: connection.password,
                    nonceCount: nonceCount, clientNonce: Self.makeClientNonce()
                ),
                forHTTPHeaderField: "Authorization"
            )
        }

        // FoundationNetworking では async の data(for:) が使えない場合があるので completion 版を使う
        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: RegzaError.network(error.localizedDescription))
                } else if let response = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), response))
                } else {
                    continuation.resume(throwing: RegzaError.network("不正なレスポンスです"))
                }
            }.resume()
        }
    }

    private func makeURL(path: String, query: String?) -> URL? {
        var host = connection.trimmedHost
        if !host.contains("://") { host = "http://" + host }
        while host.hasSuffix("/") { host.removeLast() }
        return URL(string: host + path + (query.map { "?\($0)" } ?? ""))
    }

    private static func makeClientNonce() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    /// status.htm の文字コードは機種により異なる可能性があるため、UTF-8 → Shift_JIS → EUC-JP の順に試す
    static func decode(_ data: Data) -> String {
        for encoding: String.Encoding in [.utf8, .shiftJIS, .japaneseEUC] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return String(decoding: data, as: UTF8.self)
    }
}
