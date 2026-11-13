import Foundation
import RegzaDomain
import RegzaInfrastructure

/// テレビにも録画サーバーにもつながずに動かすための、見本の返事をする通信。実在の機器の情報は入れない。
/// 本物の Repository につなぐので、返事の読み取りまでアプリと同じ処理を通る (CLI の --sample、Android の JVM のテスト)。
/// Factory に渡すと、そのアプリの通信だけを見本に置き換えられる
public struct SampleTransport: HTTPTransport {
    /// テストごとに差し替える返事 (なければ見本の返事だけ)
    public var fixture: SampleFixture

    public init(fixture: SampleFixture = SampleFixture()) {
        self.fixture = fixture
    }

    /// 見本で登録しておくテレビと録画サーバー (CLI の --sample と Android の見本で同じものを使う)。RFC 5737 の例示用のアドレス
    public static let connection = ConnectionData(host: "192.0.2.10", user: "sample", password: "sample")
    public static let guideHost = "192.0.2.20"
    public static let streamHost = "192.0.2.30"

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        // 本物の HTTPTransport と同じ種類の失敗にする
        if let host = request.url.host, fixture.unreachable.contains(host) {
            throw RegzaError.network("\(host) に接続できません")
        }
        if let response = fixture.responses[request.url.path] {
            return HTTPResponse(statusCode: response.status, headers: [:], body: Data(response.body.json.utf8))
        }
        let body: String
        switch request.url.path {
        case "/v2/remote/settings/channel_list":
            body = """
                {"status":0,"channel_list":[\
                {"channel_number":11,"rcu_channel_number":1,"channel":"JP-G00000001","name":"テスト局１","show_setting":"SHOW_REPRESENT"},\
                {"channel_number":21,"rcu_channel_number":2,"channel":"JP-G00000002","name":"テスト局２","show_setting":"SHOW_REPRESENT"},\
                {"channel_number":181,"rcu_channel_number":1,"channel":"JP-G00040001","name":"テストBS","show_setting":"SHOW"}]}
                """
        case "/v2/remote/play/status":
            let start = Int(Date().timeIntervalSince1970) - 600
            body = """
                {"status":0,"content_type":"broadcast","epg_info_current":{"channel":"JP-G00000001","channel_name":"テスト局１",\
                "channel_number":11,"rcu_channel_number":1,"start_time":\(start),"duration":3600,"title":"見本の番組"}}
                """
        case "/v2/remote/pvr/reserves/list":
            body = #"{"status":0,"rsv_list":[]}"#
        case "/remote/remote.htm":
            body = "0"
        case "/api/programs":
            body = Self.programs(query: request.url.query ?? "")
        case let path where path.hasPrefix("/api/streams/live/"):
            body = #"{"streamId":1}"#
        case "/api/streams":
            body = #"{"items":[]}"#
        case "/streamfiles/stream1.m3u8":
            body = "#EXTM3U\nsegment0.ts\n"
        default:
            body = #"{"status":0}"#
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }

    /// Mirakurun の番組表の見本。テスト局１・２に、今の正時の 1 時間前から 2 日分、1 時間ずつの番組を並べる
    static func programs(query: String) -> String {
        let names = ["見本の朝の便り", "見本の散歩", "見本の料理教室", "見本の劇場", "見本の天気"]
        let hour = Int(Date().timeIntervalSince1970) / 3600 * 3600 - 3600
        var programs: [String] = []
        for service in 1...2 where query.isEmpty || query.hasSuffix("serviceId=\(service)") {
            for index in 0..<48 {
                let id = service * 1000 + index
                let start = (hour + index * 3600) * 1000
                let name = "\(names[(index + service) % names.count]) 第\(index + 1)回"
                programs.append(
                    #"{"id":\#(id),"eventId":\#(id),"networkId":0,"serviceId":\#(service),"startAt":\#(start),"duration":3600000,"name":"\#(name)","genres":[]}"#
                )
            }
        }
        return "[" + programs.joined(separator: ",") + "]"
    }
}
