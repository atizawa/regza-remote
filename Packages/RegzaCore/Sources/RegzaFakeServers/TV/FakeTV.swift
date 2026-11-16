import Foundation
import RegzaInfrastructure
import RegzaTVAPI

/// 偽物のテレビ。チャンネル一覧・視聴中のもの・録画予約を持ち、選局や予約の操作で変わる。認証は確かめない
struct FakeTV {
    /// いま映しているもの
    enum Playing: Equatable {
        case broadcast(code: String)
        /// position は startedAt の時点の再生位置
        case recorded(position: Int, startedAt: Date)
        case standby
    }

    /// PIN での登録に使う値 (PIN 1234 で、この salt から作った鍵で暗号化したパスワード)
    enum Pairing {
        static let pin = "1234"
        static let salt = "abcdef0123456789"
        static let encryptedPassword = "c4909140d2f5f81261a1bd1d715fdc2c53ce4586b6d6dde3f16390198fee8f2c"
    }

    typealias Schemas = RegzaTVAPI.Components.Schemas

    let catalog: FakeCatalog
    var hasChannels: Bool
    var playing: Playing
    var reservations: [Schemas.Reservation]
    private var nextReservationID = 1

    init(catalog: FakeCatalog, scenario: FakeScenario, now: Date) {
        self.catalog = catalog
        hasChannels = scenario.tvHasChannels
        switch scenario.playing {
        case .broadcast: playing = .broadcast(code: catalog.stations[0].code)
        case .recorded: playing = .recorded(position: 1280, startedAt: now)
        case .standby: playing = .standby
        }
        reservations = []
        // 連ドラ予約を 1 件入れておく (2 局目の、少し先の番組)
        if scenario.hasReservation, let program = catalog.programs(code: catalog.stations[1].code).dropFirst(4).first {
            reserve(program, series: true)
        }
    }

    mutating func respond(to request: FakeRequest, now: Date) -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/public/feature"):
            return FakeResponse.json(
                Schemas.Feature(status: 0, device_type: "DTV", model: "FAKE-TV", size: "50", ipc_feature: ["PIN_Auth"]))
        case ("POST", "/v2/public/request_connection"):
            return FakeResponse.json(
                Schemas.ConnectionChallenge(status: 0, password: Pairing.encryptedPassword, salt: Pairing.salt))
        case ("POST", "/v2/public/cancel_connection"), ("POST", "/v2/remote/confirm_connection"):
            return FakeResponse.json(Schemas.Result(status: 0))
        case ("GET", "/remote/remote.htm"):
            return FakeResponse.text("0")
        case ("GET", "/remote/status.htm"):
            return FakeResponse.text(legacyStatus(now: now))
        case ("GET", "/remote/ts.htm"):
            if case .recorded = playing, let seconds = Int(request.rawQuery) {
                playing = .recorded(position: min(seconds, catalog.recording.duration), startedAt: now)
            }
            return FakeResponse.empty()
        case ("GET", "/v2/remote/play/status"):
            return FakeResponse.json(playStatus(now: now))
        case ("POST", "/v2/remote/status/channel"):
            guard let code = request.form["channel"], catalog.station(code: code) != nil else {
                return FakeResponse.json(Schemas.Result(status: 2))
            }
            playing = .broadcast(code: code)
            return FakeResponse.json(Schemas.Result(status: 0))
        case ("GET", "/v2/remote/settings/channel_list"):
            return FakeResponse.json(Schemas.ChannelList(status: 0, channel_list: hasChannels ? catalog.stations.map(Self.channel) : []))
        case ("GET", "/v2/remote/settings/timeshift"):
            return FakeResponse.json(Schemas.TimeshiftSettings(timeshift_enabled: ._false, target_channel: [], active_time_list: []))
        case ("GET", "/v2/remote/pvr/reserves/list"):
            return FakeResponse.json(Schemas.ReservationList(status: 0, rsv_list: reservations))
        case ("POST", "/v2/remote/pvr/reserves/new"):
            guard let id = request.form["epg_content_id"], let program = catalog.program(epgContentID: id) else {
                return FakeResponse.json(Schemas.Result(status: 2))
            }
            reserve(program, series: request.form["series_rec"] == "true")
            return FakeResponse.json(Schemas.Result(status: 0))
        case ("DELETE", _):
            guard let id = request.pathParameter(prefix: "/v2/remote/pvr/reserves/list/") else { return FakeResponse.notFound }
            guard reservations.contains(where: { $0.rsv_id == id }) else { return FakeResponse.json(Schemas.Result(status: 2)) }
            reservations.removeAll { $0.rsv_id == id }
            return FakeResponse.json(Schemas.Result(status: 0))
        default:
            return FakeResponse.notFound
        }
    }

    private mutating func reserve(_ program: FakeCatalog.Program, series: Bool) {
        reservations.append(
            Schemas.Reservation(
                rsv_id: String(nextReservationID), title: program.name, channel: program.channelCode,
                epg_content_id: .init(value1: program.epgContentID), start_time: Int(program.start.timeIntervalSince1970),
                duration: program.duration, _repeat: series ? "weekly" : "none", series_rec: series ? ._true : ._false))
        nextReservationID += 1
    }

    private func playStatus(now: Date) -> Schemas.PlayStatus {
        switch playing {
        case .broadcast(let code):
            let station = catalog.station(code: code)
            let current = catalog.onAir(code: code, at: now)
            let next = current.flatMap { current in catalog.programs(code: code).first { $0.start >= current.end } }
            return Schemas.PlayStatus(
                status: 0, content_type: "broadcast",
                epg_info_current: current.map { program(station, $0) } ?? program(station, nil),
                epg_info_next: next.map { program(station, $0) })
        case .recorded:
            let recording = catalog.recording
            return Schemas.PlayStatus(
                status: 0, content_type: "recorded",
                recorded_prg_info: Schemas.Program(
                    channel_name: recording.channelName, title: recording.title, duration: recording.duration),
                playing_action_info: Schemas.PlayingAction(
                    position: position(now: now), total_time: recording.duration, play_state: "play", chapter_name: recording.chapterName))
        case .standby:
            return Schemas.PlayStatus(status: 0, content_type: "other")
        }
    }

    /// 旧 API の `key=value` の行。録画再生中以外は再生の値が 0 か空
    private func legacyStatus(now: Date) -> String {
        switch playing {
        case .broadcast(let code):
            let station = catalog.station(code: code)
            return "action=0\nch_code=\(code)\nch_name=\(station?.name ?? "")\ntitle_name=\ntotal_time=0\ntitle_time=0\n"
        case .recorded:
            let recording = catalog.recording
            return """
                action=1
                ch_name=\(recording.channelName)
                title_no=1
                title_name=\(recording.title)
                total_time=\(recording.duration)
                title_time=\(position(now: now))
                chapter_no=1
                chapter_name=\(recording.chapterName)

                """
        case .standby:
            return "action=0\n"
        }
    }

    private func position(now: Date) -> Int {
        guard case .recorded(let position, let startedAt) = playing else { return 0 }
        return min(catalog.recording.duration, position + max(0, Int(now.timeIntervalSince(startedAt))))
    }

    private func program(_ station: FakeCatalog.Station?, _ program: FakeCatalog.Program?) -> Schemas.Program {
        Schemas.Program(
            channel: station?.code, channel_name: station?.name, channel_number: station?.number,
            rcu_channel_number: station?.remoteNumber, epg_content_id: program?.epgContentID, title: program?.name,
            description: program?.description, start_time: program.map { Int($0.start.timeIntervalSince1970) },
            duration: program?.duration, genre: program.map { [String(format: "00%x0", $0.genre)] })
    }

    private static func channel(_ station: FakeCatalog.Station) -> Schemas.Channel {
        Schemas.Channel(
            channel: station.code, channel_number: station.number, rcu_channel_number: station.remoteNumber, name: station.name,
            ex_channel_number: "\(station.band)_\(String(format: "%03d", station.number))",
            show_setting: station.isRepresentative ? "SHOW_REPRESENT" : "SHOW")
    }
}
