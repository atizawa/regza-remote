import Foundation
import RegzaDomain

/// 同じネットワークの機器を探すことと PIN 登録 (DeviceRepositoryProtocol の実装)
public struct NetworkDeviceRepository: DeviceRepositoryProtocol {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport) {
        self.transport = transport
    }

    public func devices() -> AsyncStream<DeviceData> {
        RegzaDiscovery.devices(transport: transport)
    }

    public func pairing(host: String, user: String) -> any PairingSession {
        RegzaPairing(host: host, user: user, transport: transport)
    }

    public func findGuideServers() async -> [String] {
        await MirakurunDiscovery.find(transport: transport)
    }

    public func findStreamServers() async -> [String] {
        await EPGStationDiscovery.find(transport: transport)
    }

    public func isStreamServer(host: String) async -> Bool {
        (try? await EPGStationAPIClient(host: host, timeout: 3, transport: transport).request(EPGStationVersionRequest())) ?? false
    }
}

extension RegzaPairing: PairingSession {}
