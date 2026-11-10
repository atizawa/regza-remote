import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct DiscoveryTests {
    /// `/public/feature` の応答の形 (値はダミー)
    let feature = """
        {"status":0,"device_type":"DTV","dtv_version":"0","id":"","ipc_version":"v2","mac":"00:00:00:00:00:00","model":"Z000","month":"Jan","region":"JP","size":"55","year":"2000","dtv_feature":["PVR"],"ipc_feature":["V1Support","PIN_Auth"]}
        """

    @Test func parsesFeature() throws {
        let device = try #require(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data(feature.utf8)))
        #expect(device.name == "REGZA 55Z000")
        #expect(device.supportsPIN)
        #expect(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data(#"{"status":0,"device_type":"BD"}"#.utf8)) == nil)
        #expect(RegzaDiscovery.device(host: "192.168.0.5", featureJSON: Data("<html>".utf8)) == nil)
    }

    @Test func enumeratesSubnet() throws {
        let address = try #require(IPv4Network.parse("192.168.0.10"))
        let hosts = IPv4Network(address: address, mask: 0xFFFF_FF00).hosts
        #expect(hosts.count == 253)
        #expect(hosts.first == "192.168.0.1")
        #expect(hosts.last == "192.168.0.254")
        #expect(!hosts.contains("192.168.0.10"))
        // /16 は自分の /24 だけ調べる
        #expect(IPv4Network(address: address, mask: 0xFFFF_0000).hosts == hosts)
    }
}
