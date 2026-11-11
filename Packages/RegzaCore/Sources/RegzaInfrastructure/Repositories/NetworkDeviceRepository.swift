import Foundation
import RegzaDomain

/// 同じネットワークの機器を探すことと PIN 登録 (DeviceRepositoryProtocol の実装)
public struct NetworkDeviceRepository: DeviceRepositoryProtocol {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = RegzaHTTP.transport) {
        self.transport = transport
    }

    public func devices() -> AsyncStream<RegzaDevice> {
        RegzaDiscovery.devices()
    }

    public func pairing(host: String, user: String) -> any PairingSession {
        RegzaPairing(host: host, user: user, transport: transport)
    }

    public func findGuideServers() async -> [String] {
        await MirakurunAPIClient.find()
    }

    public func findStreamServers() async -> [String] {
        await EPGStationAPIClient.find()
    }

    public func isStreamServer(host: String) async -> Bool {
        await EPGStationAPIClient(host: host, timeout: 3, transport: transport).isAvailable()
    }
}

extension RegzaPairing: PairingSession {}
