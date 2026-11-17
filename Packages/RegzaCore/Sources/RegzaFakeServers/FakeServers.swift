#if !REGZA_FAKES_DISABLED
import Foundation
import RegzaDomain
import RegzaInfrastructure

/// 偽物のテレビ・Mirakurun・EPGStation をまとめて持ち、宛先のアドレスで振り分ける。
/// 選局や予約で変わる状態を持つので、同じ相手に続けて送ると本物と同じように前の操作が返事に表れる
public final class FakeServers: @unchecked Sendable {
    /// 偽物のアドレス (RFC 5737 の例示用)
    public enum Host {
        public static let tv = "192.0.2.10"
        public static let guide = "192.0.2.20"
        public static let stream = "192.0.2.30"
    }

    private let lock = NSLock()
    private var tv: FakeTV
    private var mirakurun: FakeMirakurun
    private var epgStation: FakeEPGStation

    public init(scenario: FakeScenario = .standard, now: Date = Date()) {
        let catalog = FakeCatalog.standard(now: now)
        tv = FakeTV(catalog: catalog, scenario: scenario, now: now)
        mirakurun = FakeMirakurun(catalog: catalog)
        epgStation = FakeEPGStation()
    }

    /// その宛先に偽物がいなければ nil (本物と同じく、つながらない)
    func respond(to request: FakeRequest, now: Date = Date()) -> HTTPResponse? {
        lock.withLock {
            switch request.host {
            case Host.tv: tv.respond(to: request, now: now)
            case Host.guide: mirakurun.respond(to: request, now: now)
            case Host.stream: epgStation.respond(to: request)
            default: nil
            }
        }
    }
}

/// 偽物が受け取る問い合わせ (宛先・パス・クエリ・フォームの値を読みやすくしたもの)
struct FakeRequest {
    var method: String
    var host: String
    var path: String
    var query: [String: String]
    /// `?123` のように名前のないクエリ
    var rawQuery: String
    var form: [String: String]

    init(_ request: HTTPRequest) {
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        method = request.method.uppercased()
        host = request.url.host ?? ""
        path = request.url.path
        rawQuery = components?.percentEncodedQuery ?? ""
        query = Self.values(components?.queryItems)
        var formComponents = URLComponents()
        formComponents.percentEncodedQuery = request.body.map {
            String(decoding: $0, as: UTF8.self).replacingOccurrences(of: "+", with: "%20")
        }
        form = Self.values(formComponents.queryItems)
    }

    private static func values(_ items: [URLQueryItem]?) -> [String: String] {
        Dictionary((items ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
    }

    /// `/streams/{id}` の `{id}` のように、決まった前後に挟まれた部分
    func pathParameter(prefix: String, suffix: String = "") -> String? {
        guard path.hasPrefix(prefix), path.hasSuffix(suffix), path.count > prefix.count + suffix.count else { return nil }
        let value = path.dropFirst(prefix.count).dropLast(suffix.count)
        return value.contains("/") ? nil : String(value)
    }
}

enum FakeResponse {
    static func json(_ value: some Encodable, status: Int = 200) -> HTTPResponse {
        let body = (try? JSONEncoder().encode(value)) ?? Data()
        return HTTPResponse(statusCode: status, headers: ["Content-Type": "application/json"], body: body)
    }

    static func text(_ text: String) -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: ["Content-Type": "text/plain"], body: Data(text.utf8))
    }

    static func empty(status: Int = 200) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data())
    }

    static let notFound = empty(status: 404)
}
#endif
