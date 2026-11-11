import Foundation

enum EPGStationDiscovery {
    /// 同じネットワークで EPGStation が動いているアドレスを探す
    static func find(timeout: TimeInterval = 1.5, transport: any HTTPTransport = RegzaHTTP.transport) async -> [String] {
        let hosts = RegzaDiscovery.localNetworks().flatMap(\.hosts)
        var found: [String] = []
        await withTaskGroup(of: String?.self) { group in
            var iterator = hosts.makeIterator()
            for _ in 0..<RegzaDiscovery.concurrency {
                guard let host = iterator.next() else { break }
                group.addTask {
                    (try? await EPGStationAPIClient(host: host, timeout: timeout, transport: transport).request(EPGStationVersionRequest()))
                        == true ? host : nil
                }
            }
            for await host in group {
                if let host { found.append(host) }
                if let next = iterator.next() {
                    group.addTask {
                        (try? await EPGStationAPIClient(host: next, timeout: timeout, transport: transport).request(
                            EPGStationVersionRequest())) == true
                            ? next : nil
                    }
                }
            }
        }
        return found.sorted { IPv4Network.parse($0) ?? 0 < IPv4Network.parse($1) ?? 0 }
    }

}
