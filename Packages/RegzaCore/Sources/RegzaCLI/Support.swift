import Foundation
import RegzaApp

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
