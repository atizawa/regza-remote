import Foundation
import OpenAPIRuntime
import RegzaDomain
import RegzaTVAPI

/// REGZA の HTTP リモコン API クライアント。
///
/// - `GET /remote/remote.htm?key=XXXXXX` キー送信 (成功で `0`)
/// - `GET /remote/status.htm` 再生状況
/// - `GET /remote/ts.htm?SEC` シーク
///
/// いずれも Digest 認証が必要。PIN 登録は `RegzaPairing` を使う。
public actor RegzaAPIClient {
    public private(set) var connection: RegzaConnection
    private let transport: any HTTPTransport
    private let timeout: TimeInterval
    private var digest: RegzaDigestMiddleware

    public init(connection: RegzaConnection, timeout: TimeInterval = 3, transport: any HTTPTransport = RegzaHTTP.transport) {
        self.connection = connection
        self.timeout = timeout
        self.transport = transport
        self.digest = RegzaDigestMiddleware(connection: connection)
    }

    /// テレビの HTTPS のポート。録画予約の追加はこちらでしか受け付けない
    public static let securePort = 4430

    /// 接続確認などの独立した通信でも、注入された通信方式・タイムアウトを使う。
    public func replacingConnection(_ connection: RegzaConnection) -> RegzaAPIClient {
        RegzaAPIClient(connection: connection, timeout: timeout, transport: transport)
    }

    public func update(connection: RegzaConnection) {
        guard connection != self.connection else { return }
        self.connection = connection
        digest = RegzaDigestMiddleware(connection: connection)
    }

    public func send(_ key: RegzaKey) async throws {
        let body = try await generated {
            let response = try await openAPI().sendKey(query: .init(key: key.code))
            return Self.decode(try await Data(collecting: response.ok.body.plainText, upTo: 1024 * 1024))
        }
        let result = body.trimmingCharacters(in: .whitespacesAndNewlines)
        // 0 以外 (1, 2) はエラー。数値以外が返る機種は成功扱いにする
        if let code = Int(result), code != 0 {
            throw RegzaError.commandRejected(result)
        }
    }

    public func status() async throws -> RegzaStatus {
        return try await generated {
            let response = try await openAPI().getLegacyStatus()
            return RegzaStatus(text: Self.decode(try await Data(collecting: response.ok.body.plainText, upTo: 1024 * 1024)))
        }
    }

    /// v2 API の視聴状態。放送中のチャンネルや番組の時刻も取れる。
    /// 未対応の機種では `RegzaError.httpStatus(404)` か `RegzaError.unsupported` になる
    public func playStatus() async throws -> RegzaPlayStatus {
        let data = try await generated { try await JSONEncoder().encode(openAPI().getPlayStatus().ok.body.json) }
        guard let status = try? JSONDecoder().decode(RegzaPlayStatus.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard status.status == 0 else { throw RegzaError.commandRejected(String(status.status)) }
        return status
    }

    /// テレビに登録されているチャンネル。未対応の機種では `RegzaError.httpStatus(404)` か `RegzaError.unsupported` になる
    public func channels() async throws -> [RegzaChannel] {
        let data = try await generated { try await JSONEncoder().encode(openAPI().getChannels().ok.body.json) }
        guard let list = try? JSONDecoder().decode(RegzaChannelList.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        return list.channels ?? []
    }

    /// タイムシフトマシンの設定 (録画している局と時間帯)
    public func timeshiftSettings() async throws -> RegzaTimeshiftSettings {
        let data = try await generated { try await JSONEncoder().encode(openAPI().getTimeshiftSettings().ok.body.json) }
        guard let settings = try? JSONDecoder().decode(RegzaTimeshiftSettings.self, from: data) else {
            throw RegzaError.unsupported
        }
        return settings
    }

    /// 録画予約の一覧
    public func reservations() async throws -> [RegzaReservation] {
        let data = try await generated { try await JSONEncoder().encode(openAPI().getReservations().ok.body.json) }
        guard let list = try? JSONDecoder().decode(RegzaReservationList.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard list.status == 0 else { throw RegzaError.commandRejected(String(list.status)) }
        return list.reservations ?? []
    }

    /// 番組を録画予約する (`POST /v2/remote/pvr/reserves/new`)。保存先などはテレビの設定どおり。
    /// `series` なら連ドラ予約にする。繰り返し (毎週・月〜金など) とキーワードはテレビが番組から決める
    /// (`series_rec=true` だけを送ると受け付けられ、`repeat_series` などを自分で入れると status 2 になった)
    public func reserve(channel: String, epgContentID: String, start: Date, duration: Int, series: Bool = false) async throws {
        let data = try await generated {
            try await JSONEncoder().encode(
                openAPI(secure: true).addReservation(
                    body: .urlEncodedForm(
                        .init(
                            channel: channel, epg_content_id: epgContentID, start_time: Int(start.timeIntervalSince1970),
                            duration: duration, series_rec: series ? ._true : nil
                        ))
                ).ok.body.json)
        }
        try Self.checkResult(data)
    }

    /// 録画予約を取り消す (`DELETE /v2/remote/pvr/reserves/list/:rsv_id`)
    public func cancelReservation(id: String) async throws {
        let data = try await generated {
            try await JSONEncoder().encode(openAPI().cancelReservation(path: .init(rsv_id: id)).ok.body.json)
        }
        try Self.checkResult(data)
    }

    /// `{"status":0}` 以外はテレビに断られた
    private static func checkResult(_ data: Data) throws {
        guard let result = try? JSONDecoder().decode(RegzaResult.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard result.status == 0 else { throw RegzaError.commandRejected(String(result.status)) }
    }

    /// チャンネル一覧の `code` で選局する (`POST /v2/remote/status/channel`)
    public func tune(to code: String) async throws {
        let data = try await generated {
            try await JSONEncoder().encode(openAPI().tune(body: .urlEncodedForm(.init(channel: code))).ok.body.json)
        }
        try Self.checkResult(data)
    }

    /// 録画再生中に指定秒数の位置へ移動する
    public func seek(to seconds: Int) async throws {
        _ = try await generated { try await openAPI(queryOverride: String(max(0, seconds))).seek() }
    }

    func openAPI(secure: Bool = false, queryOverride: String? = nil) throws -> Client {
        guard connection.isConfigured else { throw RegzaError.notConfigured }
        var host = connection.trimmedHost
        if !host.contains("://") { host = "http://" + host }
        while host.hasSuffix("/") { host.removeLast() }
        guard var components = URLComponents(string: host), components.host != nil else { throw RegzaError.invalidHost }
        if secure {
            components.scheme = "https"
            components.port = Self.securePort
        }
        guard let url = components.url else { throw RegzaError.invalidHost }
        return Client(
            serverURL: url,
            transport: OpenAPIHTTPTransport(transport: transport, timeout: timeout),
            middlewares: [
                RegzaResponseMiddleware(),
                RegzaCompatibilityMiddleware(queryOverride: queryOverride),
                digest,
            ]
        )
    }

    /// status.htm の文字コードは機種により異なる可能性があるため、UTF-8 → Shift_JIS → EUC-JP の順に試す
    static func decode(_ data: Data) -> String {
        for encoding: String.Encoding in [.utf8, .shiftJIS, .japaneseEUC] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return String(decoding: data, as: UTF8.self)
    }
}
