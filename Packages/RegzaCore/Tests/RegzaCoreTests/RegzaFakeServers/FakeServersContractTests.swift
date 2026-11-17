import Foundation
import Testing

@testable import RegzaDomain
@testable import RegzaFakeServers
@testable import RegzaInfrastructure

/// 偽物の返事を、本物の API クライアントと返事の読み取りで読めること (偽物と本物の API の約束がずれていないこと)
@Suite struct FakeServersContractTests {
    let transport = FakeServersTransport()
    var tv: RegzaAPIClient { RegzaAPIClient(connection: FakeScenario.connection, transport: transport) }
    var mirakurun: MirakurunAPIClient { MirakurunAPIClient(host: FakeServers.Host.guide, transport: transport) }
    var epgStation: EPGStationAPIClient { EPGStationAPIClient(host: FakeServers.Host.stream, transport: transport) }

    @Test func tvChannelsAndStatus() async throws {
        let channels = try await tv.request(RegzaChannelsRequest())
        #expect(channels.map(\.name) == ["テスト局１", "テスト局２", "テストBS"])
        #expect(channels.map(\.isRepresentative) == [true, true, false])

        let status = try await tv.request(RegzaPlayStatusRequest())
        let onAir = try #require(FakeCatalog.standard().onAir(code: channels[0].code, at: Date()))
        #expect(status.contentType == "broadcast")
        #expect(status.currentProgram?.channel == channels[0].code)
        #expect(status.currentProgram?.title == onAir.name)
        #expect(status.nextProgram?.startTime == Int(onAir.end.timeIntervalSince1970))

        let legacy = try await tv.request(RegzaLegacyStatusRequest())
        #expect(legacy.channelCode == channels[0].code)
        #expect(!legacy.isPlayingRecording)
        _ = try await tv.request(RegzaTimeshiftSettingsRequest())
        try await tv.request(RegzaSendKeyRequest(key: .power))
    }

    /// 選局すると、視聴中のものがその局に変わる
    @Test func tuneChangesPlayStatus() async throws {
        let code = BroadcastID.channelCode(networkId: 0, serviceId: 2)
        try await tv.request(RegzaTuneRequest(code: code))
        #expect(try await tv.request(RegzaPlayStatusRequest()).currentProgram?.channelName == "テスト局２")
        await #expect(throws: RegzaError.commandRejected("2")) { try await tv.request(RegzaTuneRequest(code: "JP-G99999999")) }
    }

    /// 予約すると一覧に載り、取り消すと消える
    @Test func reservations() async throws {
        let initial = try await tv.request(RegzaReservationsRequest())
        #expect(initial.map(\.isSeries) == [true])
        let program = try #require(FakeCatalog.standard().programs.last)
        try await tv.request(
            RegzaReserveRequest(
                channel: program.channelCode, epgContentID: program.epgContentID, start: program.start, duration: program.duration,
                series: false))
        let reserved = try await tv.request(RegzaReservationsRequest())
        let added = try #require(reserved.last)
        #expect(added.title == program.name)
        #expect(added.epgContentID == program.epgContentID)

        try await tv.request(RegzaCancelReservationRequest(id: added.id))
        #expect(try await tv.request(RegzaReservationsRequest()).map(\.id) == initial.map(\.id))
    }

    @Test func pairing() async throws {
        let pairing = RegzaPairing(host: FakeServers.Host.tv, user: "02-00-00-00-00-01", transport: transport)
        try await pairing.start()
        await #expect(throws: RegzaError.invalidPIN) { try await pairing.confirm(pin: "0000") }
        let connection = try await pairing.confirm(pin: FakeTV.Pairing.pin)
        #expect(connection.host == FakeServers.Host.tv)
        #expect(!connection.password.isEmpty)
    }

    /// PIN の表示を取り消す
    @Test func cancelPairing() async throws {
        try await tv.request(RegzaStartPairingRequest(user: "02-00-00-00-00-01"))
        try await tv.request(RegzaCancelPairingRequest(user: "02-00-00-00-00-01"))
    }

    /// テレビの API の定義 (OpenAPI/regza-tv.yaml) にある操作には、どれも偽物が答える (定義に足した操作を、偽物に足し忘れない)
    @Test func tvAnswersEveryOperationInTheSpec() async throws {
        let spec = try String(contentsOf: Self.repository.appending(path: "OpenAPI/regza-tv.yaml"), encoding: .utf8)
        var operations: [(method: String, path: String)] = []
        var path: String?
        for line in spec.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("  /"), line.hasSuffix(":") {
                path = String(line.dropFirst(2).dropLast())
            } else if let path, line.hasPrefix("    "), !line.hasPrefix("     "),
                let method = ["get", "post", "put", "delete"].first(where: { line == "    \($0):" })
            {
                operations.append((method.uppercased(), path))
            } else if !line.hasPrefix(" "), !line.isEmpty {
                path = nil
            }
        }
        // 定義の読み取りが壊れていないこと
        #expect(operations.count >= 14)
        for operation in operations {
            // 標準の場面には、予約 (ID 1) が 1 件ある
            let path = operation.path.replacingOccurrences(of: "{rsv_id}", with: "1")
            let url = try #require(URL(string: "http://\(FakeServers.Host.tv)\(path)"))
            let response = try await transport.send(HTTPRequest(method: operation.method, url: url, timeout: 3))
            #expect(response.statusCode == 200, "\(operation.method) \(operation.path)")
        }
    }

    static let repository = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test func discoveryFindsOnlyTheTV() async {
        let device = await RegzaDiscovery.probe(host: FakeServers.Host.tv, transport: transport)
        #expect(device?.supportsPIN == true)
        #expect(await RegzaDiscovery.probe(host: FakeServers.Host.guide, transport: transport) == nil)
        #expect(await RegzaDiscovery.probe(host: "192.0.2.99", transport: transport) == nil)
    }

    @Test func recordedPlaying() async throws {
        let tv = tvClient(FakeScenario(.recordedPlaying))
        let status = try await tv.request(RegzaPlayStatusRequest())
        #expect(status.contentType == "recorded")
        #expect(status.recordedProgram?.title == "見本の録画番組")
        try await tv.request(RegzaSeekRequest(seconds: 60))
        let legacy = try await tv.request(RegzaLegacyStatusRequest())
        #expect(legacy.isPlayingRecording)
        #expect((60...61).contains(legacy.titleTime))
    }

    @Test func guidePrograms() async throws {
        #expect(try await mirakurun.request(MirakurunVersionRequest()))
        let all = try await mirakurun.request(MirakurunAllProgramsRequest())
        #expect(all.count == 96)
        let first = try #require(all.first)
        let channel = try await mirakurun.request(MirakurunChannelProgramsRequest(networkID: first.networkId, serviceID: first.serviceId))
        #expect(channel.count == 48)
        #expect(try await mirakurun.request(MirakurunProgramRequest(id: first.id)).name == first.name)
        // 出演者を「拡張」の情報として持つ番組がある
        #expect(all.contains { $0.extended.contains { $0.title == "出演者" } })
    }

    /// 配信を頼むと番号が返り、プレイリストが読めて、止めると消える
    @Test func liveStream() async throws {
        #expect(try await epgStation.request(EPGStationVersionRequest()))
        let streamID = try await epgStation.request(EPGStationStartStreamRequest(channelID: 100_001, mode: 0))
        #expect(try await executeAPIRequest(EPGStationPlaylistRequest(streamID: streamID), using: epgStation.playlistContext()))
        try await epgStation.request(EPGStationKeepStreamRequest(streamID: streamID))
        #expect(try await epgStation.request(EPGStationStreamsRequest()).map(\.id) == [streamID])
        try await epgStation.request(EPGStationStopStreamRequest(streamID: streamID))
        #expect(try await epgStation.request(EPGStationStreamsRequest()).isEmpty)
        await #expect(throws: RegzaError.httpStatus(404)) { try await epgStation.request(EPGStationStopStreamRequest(streamID: streamID)) }
    }
}

/// 名前の場面と、JSON での差し替え
@Suite struct FakeScenarioTests {
    @Test func unreachableHostFailsLikeTheRealNetwork() async {
        let tv = tvClient(FakeScenario(.tvUnreachable))
        await #expect(throws: RegzaError.self) { try await tv.request(RegzaChannelsRequest()) }
    }

    @Test func emptyChannels() async throws {
        let tv = tvClient(FakeScenario(.emptyChannels))
        #expect(try await tv.request(RegzaChannelsRequest()).isEmpty)
    }

    @Test func jsonAddsToTheNamedScenario() throws {
        let scenario = try FakeScenario(
            json: #"""
                {"base":"noGuideServer","unreachable":["192.0.2.30"],"responses":{"/v2/remote/pvr/reserves/list":{"body":{"status":0}}}}
                """#)
        #expect(!scenario.registersGuide)
        #expect(scenario.unreachable == ["192.0.2.30"])
        #expect(scenario.responses["/v2/remote/pvr/reserves/list"]?.status == 200)
        #expect(throws: (any Error).self) { try FakeScenario(json: #"{"base":"unknown"}"#) }
    }

    @Test func registration() {
        let secureStorageManager = SecureStorageManager(storage: MemorySecureStorage())
        let preferencesManager = PreferencesManager(storage: MemoryPreferencesStorage())
        FakeScenario(.noGuideServer).register(secureStorageManager: secureStorageManager, preferencesManager: preferencesManager)
        #expect(preferencesManager.value(forKey: .host) == FakeServers.Host.tv)
        #expect(preferencesManager.value(forKey: .guideHost) == nil)
        #expect(preferencesManager.value(forKey: .streamHost) == FakeServers.Host.stream)

        let empty = PreferencesManager(storage: MemoryPreferencesStorage())
        FakeScenario(.notRegistered).register(secureStorageManager: secureStorageManager, preferencesManager: empty)
        #expect(empty.value(forKey: .host) == nil)
    }
}

private func tvClient(_ scenario: FakeScenario) -> RegzaAPIClient {
    RegzaAPIClient(connection: FakeScenario.connection, transport: FakeServersTransport(scenario: scenario))
}

/// 偽物のどのファイルも、iOS のリリースのビルドで中身がなくなるよう `#if !REGZA_FAKES_DISABLED` で囲んである
/// (iOS の画面のモジュールはプレビューのために偽物に依存するので、囲み忘れたファイルはリリース版のアプリに入る)
@Suite struct FakeServersReleaseGuardTests {
    @Test func everyFileIsGuarded() throws {
        let sources = FakeServersContractTests.repository.appending(path: "Packages/RegzaCore/Sources/RegzaFakeServers")
        let paths = try FileManager.default.subpathsOfDirectory(atPath: sources.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") }
        #expect(!paths.isEmpty)
        for path in paths {
            let source = try String(contentsOf: sources.appending(path: path), encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(
                source.hasPrefix("#if !REGZA_FAKES_DISABLED\n") && source.hasSuffix("#endif"),
                "\(path) を #if !REGZA_FAKES_DISABLED で囲んでください")
        }
    }
}
