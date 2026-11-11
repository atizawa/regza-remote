import Foundation
import RegzaDomain

// Mockolo が生成したモックの、複数のテストで共有する初期値。
// 呼び出し記録・protocol の実装は Generated/DomainMocks.swift が担当する。
extension TVRepositoryProtocolMock {
    convenience init(connection: ConnectionData, channels: [ChannelData], nowPlaying: NowPlayingData?) {
        self.init(connection: connection, channels: channels)
        lastNowPlayingHandler = { nowPlaying }
        refreshHandler = { () throws(RegzaError) in
            guard let nowPlaying else { throw .notConfigured }
            return nowPlaying
        }
        saveHandler = { [weak self] in self?.connection = $0 }
    }
}

extension GuideRepositoryProtocolMock {
    convenience init(guideHost: String, programs: [ProgramData]) {
        self.init(
            guideHost: guideHost,
            guidePrograms: Dictionary(grouping: programs, by: \.channelCode)
                .mapValues { $0.sorted { $0.start < $1.start } },
            guideProgramsLoadedAt: programs.isEmpty ? nil : Date(timeIntervalSince1970: 1))
        programsHandler = { [weak self] in self?.guidePrograms[$0] ?? [] }
        programHandler = { [weak self] id, channelCode in
            self?.guidePrograms[channelCode]?.first { $0.id == id }
        }
        saveGuideHostHandler = { [weak self] in self?.guideHost = $0 }
    }
}

extension StreamRepositoryProtocolMock {
    convenience init(streamHost: String) {
        self.init(streamHost: streamHost, canStream: !streamHost.isEmpty)
        saveStreamHostHandler = { [weak self] in self?.streamHost = $0 }
        isPlayableHandler = { _ in true }
    }
}

extension DeviceRepositoryProtocolMock {
    convenience init(foundDevices: [DeviceData], streamServerHosts: Set<String>) {
        self.init()
        devicesHandler = {
            AsyncStream { continuation in
                for device in foundDevices { continuation.yield(device) }
                continuation.finish()
            }
        }
        isStreamServerHandler = { streamServerHosts.contains($0) }
    }
}
