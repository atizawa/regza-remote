import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaSample

/// SetupUseCase (設定) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct SetupUseCaseTests {
    @Test func unlinkingGuideAlsoUnlinksStream() async {
        let guide = SampleGuideRepository(guideHost: "192.0.2.2", programs: [])
        let stream = SampleStreamRepository()
        stream.saveStreamHost("192.0.2.2:8888")
        let setup = SetupUseCase(devices: RecordingDeviceRepository(), guide: guide, stream: stream)

        setup.unlinkStream()
        #expect(setup.linkedGuideHost == "192.0.2.2")
        #expect(setup.linkedStreamHost == "")

        stream.saveStreamHost("192.0.2.2:8888")
        // EPGStation は Mirakurun から放送を受け取るので、番組表を外したらライブ視聴も外す
        await setup.unlinkGuide()
        #expect(setup.linkedGuideHost == "")
        #expect(setup.linkedStreamHost == "")
    }

    @Test func setupFindsDevicesAndStreamServer() async {
        let setup = SetupUseCase(
            devices: RecordingDeviceRepository(),
            guide: SampleGuideRepository(guideHost: "", programs: []),
            stream: SampleStreamRepository()
        )
        var found: [DeviceItem] = []
        for await device in setup.findTVs() { found.append(device) }
        #expect(found == [DeviceItem(host: "192.0.2.10", name: "REGZA 55Z000", supportsPIN: true)])

        #expect(await setup.streamServer(sameAs: "192.0.2.2") == "192.0.2.2")
        #expect(await setup.streamServer(sameAs: "192.0.2.3") == nil)
        #expect(await setup.streamServer(sameAs: "") == nil)
    }
}
