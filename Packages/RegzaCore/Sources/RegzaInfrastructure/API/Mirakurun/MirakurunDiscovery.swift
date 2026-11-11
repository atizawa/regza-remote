import Foundation

enum MirakurunDiscovery {
    /// 同じネットワークで Mirakurun が動いているアドレスを探す
    static func find(timeout: TimeInterval = 1.5) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask {
                    (try? await MirakurunAPIClient(host: host, timeout: timeout).request(MirakurunVersionRequest())) == true ? host : nil
                }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask {
                        (try? await MirakurunAPIClient(host: next, timeout: timeout).request(MirakurunVersionRequest())) == true
                            ? next : nil
                    }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }
}
