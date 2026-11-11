import Foundation
import Testing

@testable import RegzaDomain

/// SetupUseCase (設定) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct SetupUseCaseTests {
    @Test func unlinkingGuideAlsoUnlinksStream() async {
        let guideRepository = GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: [])
        let streamRepository = StreamRepositoryProtocolMock(streamHost: "192.0.2.30")
        streamRepository.saveStreamHost("192.0.2.2:8888")
        let setupUseCase = SetupUseCase(
            deviceRepository: DeviceRepositoryProtocolMock(), guideRepository: guideRepository, streamRepository: streamRepository)

        setupUseCase.unlinkStream()
        #expect(setupUseCase.linkedGuideHost == "192.0.2.2")
        #expect(setupUseCase.linkedStreamHost == "")

        streamRepository.saveStreamHost("192.0.2.2:8888")
        // EPGStation は Mirakurun から放送を受け取るので、番組表を外したらライブ視聴も外す
        await setupUseCase.unlinkGuide()
        #expect(setupUseCase.linkedGuideHost == "")
        #expect(setupUseCase.linkedStreamHost == "")
    }

    @Test func setupFindsDevicesAndStreamServer() async {
        let setupUseCase = SetupUseCase(
            deviceRepository: DeviceRepositoryProtocolMock(
                foundDevices: [DeviceData(host: "192.0.2.10", model: "Z000", size: "55", supportsPIN: true)],
                streamServerHosts: ["192.0.2.2"]),
            guideRepository: GuideRepositoryProtocolMock(guideHost: "", programs: []),
            streamRepository: StreamRepositoryProtocolMock(streamHost: "192.0.2.30")
        )
        var found: [DeviceItem] = []
        for await device in setupUseCase.findTVs() { found.append(device) }
        #expect(found == [DeviceItem(host: "192.0.2.10", name: "REGZA 55Z000", supportsPIN: true)])

        #expect(await setupUseCase.streamServer(sameAs: "192.0.2.2") == "192.0.2.2")
        #expect(await setupUseCase.streamServer(sameAs: "192.0.2.3") == nil)
        #expect(await setupUseCase.streamServer(sameAs: "") == nil)
    }
}
