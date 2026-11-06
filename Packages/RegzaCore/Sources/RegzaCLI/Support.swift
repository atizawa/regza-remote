import Foundation
import RegzaCore

/// 保存しない保存先 (CLI を閉じたら消える)
final class MemoryConnectionStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private var hosts = (guide: "", stream: "")
    private var streams: [Int] = []

    init(connection: RegzaConnection) {
        self.connection = connection
    }

    func load() -> RegzaConnection { lock.withLock { connection } }
    func save(_ connection: RegzaConnection) { lock.withLock { self.connection = connection } }
    func pairingUserID() -> String { "00:00:5e:00:53:01" }

    var guideHost: String {
        get { lock.withLock { hosts.guide } }
        set { lock.withLock { hosts.guide = newValue } }
    }

    var streamHost: String {
        get { lock.withLock { hosts.stream } }
        set { lock.withLock { hosts.stream = newValue } }
    }

    var ownStreamIDs: [Int] {
        get { lock.withLock { streams } }
        set { lock.withLock { streams = newValue } }
    }
}

/// テレビにつながずに動かすための見本の返事。実在の機器の情報は入れない
struct SampleTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
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
        default:
            body = #"{"status":0}"#
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }
}
