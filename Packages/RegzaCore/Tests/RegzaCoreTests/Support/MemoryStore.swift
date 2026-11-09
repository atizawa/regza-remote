import Foundation
@testable import RegzaDomain
@testable import RegzaInfrastructure

final class MemoryStore: RegzaConnectionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var connection: RegzaConnection
    private var values: (guideHost: String, streamHost: String, ownStreamIDs: [Int]) = ("", "", [])

    init(connection: RegzaConnection) {
        self.connection = connection
    }

    func load() -> RegzaConnection {
        lock.lock(); defer { lock.unlock() }
        return connection
    }

    func save(_ connection: RegzaConnection) {
        lock.lock(); self.connection = connection; lock.unlock()
    }

    func pairingUserID() -> String { "00:00:5e:00:53:00" }

    var guideHost: String {
        get { lock.lock(); defer { lock.unlock() }; return values.guideHost }
        set { lock.lock(); values.guideHost = newValue.trimmingCharacters(in: .whitespaces); lock.unlock() }
    }

    var streamHost: String {
        get { lock.lock(); defer { lock.unlock() }; return values.streamHost }
        set { lock.lock(); values.streamHost = newValue; lock.unlock() }
    }

    var ownStreamIDs: [Int] {
        get { lock.lock(); defer { lock.unlock() }; return values.ownStreamIDs }
        set { lock.lock(); values.ownStreamIDs = newValue; lock.unlock() }
    }
}
