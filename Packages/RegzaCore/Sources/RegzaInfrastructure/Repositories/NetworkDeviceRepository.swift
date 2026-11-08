import Foundation
import RegzaDomain

/// 同じネットワークの機器を探すことと PIN 登録 (DeviceRepository の実装)
public struct NetworkDeviceRepository: DeviceRepository {
    private let transport: any HTTPTransport

    public init(transport: any HTTPTransport = RegzaHTTP.transport) {
        self.transport = transport
    }

    public func devices() -> AsyncStream<RegzaDevice> {
        RegzaDiscovery.devices()
    }

    public func pairing(host: String, user: String) -> any PairingSession {
        RegzaPairing(host: host, user: user)
    }

    public func findGuideServers() async -> [String] {
        await Mirakurun.find()
    }

    public func findStreamServers() async -> [String] {
        await EPGStation.find()
    }

    public func isStreamServer(host: String) async -> Bool {
        await EPGStation(host: host, timeout: 3, transport: transport).isAvailable()
    }
}

extension RegzaPairing: PairingSession {}
