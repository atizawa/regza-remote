import Foundation
import Testing

@testable import RegzaDomain

/// ChannelUseCase (チャンネル) がエンティティから UI の型を作るところと、手順や決まりを確かめる (通信はしない)
@MainActor
@Suite struct ChannelUseCaseTests {
    @Test func channelItemsHideSubchannelsUnlessWatching() throws {
        let channels = try TestData.channels()
        let programs = [
            try TestData.program(id: 1, serviceId: 1, start: TestData.date(hour: 12, minute: 30), minutes: 60, name: "代表の番組"),
            try TestData.program(
                id: 2, serviceId: 0x11, start: TestData.date(hour: 12, minute: 30), minutes: 60, name: "代表の番組"),
        ]
        let tvRepository = TVRepositoryProtocolMock(connection: ConnectionData(host: "192.0.2.1"), channels: channels, nowPlaying: nil)
        let useCase = ChannelUseCase(
            tvRepository: tvRepository, guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: programs))

        #expect(useCase.bands == [.terrestrial, .bs, .cs])
        // サブチャンネルは代表と同じ番組なので出さない
        let items = useCase.items(band: .terrestrial, nowPlayingCode: nil, now: TestData.now)
        #expect(items.map(\.name) == ["テスト局１"])
        let item = try #require(items.first)
        #expect(item.numberText == "011")
        #expect(item.programName == "代表の番組")
        #expect(item.hasPrograms)
        #expect(!item.isNowPlaying)
        #expect(!item.canStartOver)

        // 見ているときはサブチャンネルも出し、控えめに出す印を付ける
        let watching = useCase.items(band: .terrestrial, nowPlayingCode: "JP-G00000011", now: TestData.now)
        #expect(watching.map(\.name) == ["テスト局１", "テスト局１サブ"])
        #expect(watching.last?.isNowPlaying == true)
        #expect(watching.last?.isSubchannel == true)

        #expect(useCase.items(band: .cs, nowPlayingCode: nil, now: TestData.now).map(\.name) == ["テストCS"])
        #expect(useCase.channel(code: "JP-G00040001")?.name == "テストBS")
    }

    @Test func liveChannelsAreThoseMirakurunReceives() throws {
        let channels = try TestData.channels()
        let tvRepository = TVRepositoryProtocolMock(connection: ConnectionData(host: "192.0.2.1"), channels: channels, nowPlaying: nil)
        // 番組表がまだなければ、CS 以外の代表のチャンネル
        let noGuideUseCase = ChannelUseCase(
            tvRepository: tvRepository, guideRepository: GuideRepositoryProtocolMock(guideHost: "192.0.2.2", programs: []))
        #expect(noGuideUseCase.liveBands == [.terrestrial, .bs])
        #expect(
            noGuideUseCase.liveItems(band: .terrestrial, watchingCode: "JP-G00000001", now: TestData.now).map(\.name) == ["テスト局１"])

        // 番組表があれば、番組表がある (Mirakurun が受信している) 局だけ
        let withGuideUseCase = ChannelUseCase(
            tvRepository: tvRepository,
            guideRepository: GuideRepositoryProtocolMock(
                guideHost: "192.0.2.2",
                programs: [
                    try TestData.program(id: 1, networkId: 4, serviceId: 1, start: TestData.now)
                ]))
        #expect(withGuideUseCase.liveBands == [.bs])
        let bs = withGuideUseCase.liveItems(band: .bs, watchingCode: "JP-G00040001", now: TestData.now)
        #expect(bs.map(\.name) == ["テストBS"])
        #expect(bs.first?.isNowPlaying == true)
    }
}
