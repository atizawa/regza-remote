import Foundation
import RegzaDomain

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

/// 同じネットワーク内のアドレスに `/public/feature` を問い合わせて REGZA を探す。
///
/// SSDP のマルチキャストは iOS では特別な entitlement が必要なので使わない。
public enum RegzaDiscovery {
    /// 一度に問い合わせる数
    static let concurrency = 96

    /// 見つかったテレビを IP アドレス順に返す
    public static func scan(timeout: TimeInterval = 1.5) async -> [DeviceData] {
        var found: [DeviceData] = []
        for await device in devices(timeout: timeout) { found.append(device) }
        return found.sorted { IPv4Network.parse($0.host) ?? 0 < IPv4Network.parse($1.host) ?? 0 }
    }

    /// 見つかった順にテレビを流す。全アドレスを調べ終えると終わる
    public static func devices(timeout: TimeInterval = 1.5) -> AsyncStream<DeviceData> {
        AsyncStream { continuation in
            let task = Task {
                let hosts = localNetworks().flatMap(\.hosts)
                await withTaskGroup(of: DeviceData?.self) { group in
                    var iterator = hosts.makeIterator()
                    for _ in 0..<concurrency {
                        guard let host = iterator.next() else { break }
                        group.addTask { await probe(host: host, timeout: timeout) }
                    }
                    for await device in group {
                        if let device { continuation.yield(device) }
                        if !Task.isCancelled, let host = iterator.next() {
                            group.addTask { await probe(host: host, timeout: timeout) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// IP アドレスが変わったテレビを探し、新しいアドレスを返す。
    /// 登録はテレビごとなので、保存済みの資格情報で認証が通ったものを同じテレビとみなす
    public static func locate(_ connection: ConnectionData, timeout: TimeInterval = 1.5) async -> String? {
        for await device in devices(timeout: timeout) where device.host != connection.trimmedHost {
            var candidate = connection
            candidate.host = device.host
            if await authenticates(candidate) { return device.host }
        }
        return nil
    }

    private static func authenticates(_ connection: ConnectionData) async -> Bool {
        let regzaAPIClient = RegzaAPIClient(connection: connection)
        do {
            _ = try await regzaAPIClient.request(RegzaPlayStatusRequest())
            return true
        } catch RegzaError.commandRejected {
            // 認証は通っている
            return true
        } catch RegzaError.httpStatus(404), RegzaError.unsupported {
            // v2 API が無い機種は旧 API で確かめる
            return (try? await regzaAPIClient.request(RegzaLegacyStatusRequest())) != nil
        } catch {
            return false
        }
    }

    /// 1 台に問い合わせる。REGZA でなければ nil
    public static func probe(
        host: String, timeout: TimeInterval = 1.5, transport: any HTTPTransport = RegzaHTTP.transport
    ) async -> DeviceData? {
        let regzaAPIClient = RegzaAPIClient(connection: ConnectionData(host: host), timeout: timeout, transport: transport)
        guard let feature = try? await regzaAPIClient.request(RegzaFeatureRequest()) else { return nil }
        return device(host: host, feature: feature)
    }

    static func device(host: String, featureJSON data: Data) -> DeviceData? {
        guard let feature = try? JSONDecoder().decode(RegzaFeatureResponse.self, from: data) else { return nil }
        return device(host: host, feature: feature)
    }

    private static func device(host: String, feature: RegzaFeatureResponse) -> DeviceData? {
        guard feature.isTV else { return nil }
        return DeviceData(
            host: host,
            model: feature.model ?? "",
            size: feature.size ?? "",
            supportsPIN: feature.ipcFeature?.contains("PIN_Auth") ?? false
        )
    }

    /// Wi-Fi・有線 LAN の IPv4 ネットワーク (モバイル通信や VPN は除く)
    static func localNetworks() -> [IPv4Network] {
        var networks: [IPv4Network] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(bitPattern: UInt32(interface.ifa_flags))
            // Android では ifa_name が Optional になっている
            let name = interface.ifa_name.map { String(cString: $0) } ?? ""
            guard flags & interfaceUp != 0, flags & interfaceLoopback == 0,
                ["en", "wlan", "eth"].contains(where: name.hasPrefix),
                let address = interface.ifa_addr, let netmask = interface.ifa_netmask,
                address.pointee.sa_family == sa_family_t(AF_INET)
            else { continue }
            let network = IPv4Network(address: ipv4(address), mask: ipv4(netmask))
            if !networks.contains(network) { networks.append(network) }
        }
        return networks
    }

    // Android では IFF_UP などが数値ではなく net_device_flags の値になっている
    #if canImport(Android)
    private static let interfaceUp = Int32(truncatingIfNeeded: IFF_UP.rawValue)
    private static let interfaceLoopback = Int32(truncatingIfNeeded: IFF_LOOPBACK.rawValue)
    #else
    private static let interfaceUp = Int32(IFF_UP)
    private static let interfaceLoopback = Int32(IFF_LOOPBACK)
    #endif

    private static func ipv4(_ pointer: UnsafeMutablePointer<sockaddr>) -> UInt32 {
        pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
    }
}

struct IPv4Network: Equatable {
    /// 自分のアドレス (ホストバイトオーダー)
    var address: UInt32
    var mask: UInt32

    /// 自分以外のアドレス。/24 より広いネットワークは時間がかかるので自分の /24 だけにする
    var hosts: [String] {
        let mask = max(self.mask, 0xFFFF_FF00)
        let network = address & mask
        let broadcast = network | ~mask
        guard broadcast > network + 1 else { return [] }
        return (network + 1..<broadcast).filter { $0 != address }.map(Self.format)
    }

    static func format(_ value: UInt32) -> String {
        (0..<4).reversed().map { String(value >> (8 * UInt32($0)) & 0xFF) }.joined(separator: ".")
    }

    static func parse(_ string: String) -> UInt32? {
        let parts = string.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 < 256 }) else { return nil }
        return parts.reduce(0) { $0 << 8 | $1 }
    }
}
