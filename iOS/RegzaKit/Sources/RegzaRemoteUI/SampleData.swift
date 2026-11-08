#if os(iOS) && DEBUG
import Foundation
import RegzaCore
import RegzaSample

/// 開発中に、テレビや Mirakurun につながずに画面を確かめるための見本データ。
/// 起動引数 `-SampleData YES` で使う (`-SampleKind recorded` で録画再生中、`-InitialTab guide` などで最初のタブ、
/// `-SampleNoGuide YES` で Mirakurun が未設定のとき、`-ShowSettings YES` で設定画面を開く、
/// `-SampleSearch 言葉` で番組表を検索しておく)。
/// 実在の機器の情報は入れない
enum SampleData {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "SampleData") }

    /// 見本の Repository で、アプリ全体の ViewModel を組み立てる (テレビにつながない)
    @MainActor
    static func makeApp() -> AppViewModel {
        let connection = RegzaConnection(host: "192.0.2.1")
        // -SampleNoGuide YES で Mirakurun が未設定のときの画面を確かめる
        guard !UserDefaults.standard.bool(forKey: "SampleNoGuide") else {
            return .sample(connection: connection, nowPlaying: nowPlaying(), channels: channels())
        }
        let programs = programs()
        return .sample(
            connection: connection, nowPlaying: nowPlaying(), channels: channels(),
            guideHost: "192.0.2.2", programs: programs, reservations: reservations(programs: programs)
        )
    }

    static var initialTab: AppViewModel.Tab? {
        switch UserDefaults.standard.string(forKey: "InitialTab") {
        case "guide": .guide
        case "channels": .channels
        case "reservations": .reservations
        case "remote": .remote
        default: nil
        }
    }

    static func nowPlaying(now: Date = Date()) -> RegzaNowPlaying {
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        if UserDefaults.standard.string(forKey: "SampleKind") == "recorded" {
            return RegzaNowPlaying(
                kind: .recorded, channelName: "みどりテレビ", title: "週末の旅　海辺の町をめぐる",
                description: "見本の録画番組です。", position: 1280, duration: 3240, isAdvancing: true, updatedAt: now
            )
        }
        return RegzaNowPlaying(
            kind: .broadcast, channelName: "みどりテレビ", channelCode: code(1, 1), title: "夜のニュース",
            position: Int(now.timeIntervalSince(hour)), duration: 3600, isAdvancing: true,
            nextProgramStart: hour.addingTimeInterval(3600), nextProgramDuration: 1800, nextTitle: "天気予報",
            updatedAt: now
        )
    }

    static let stations: [(name: String, band: String, number: Int)] = [
        ("みどりテレビ", "DUV", 11), ("あおぞら放送", "DUV", 21), ("さくらテレビ", "DUV", 41),
        ("やまびこ放送", "DUV", 51), ("ひかりテレビ", "DUV", 61), ("こがねチャンネル", "DUV", 81),
        ("BSみどり", "DBS", 101), ("BSあおぞら", "DBS", 141), ("BSさくら", "DBS", 161),
        ("CSシネマ", "DCS", 201),
    ]

    private static func code(_ network: Int, _ service: Int) -> String {
        BroadcastID.channelCode(networkId: network, serviceId: service)
    }

    static func channels() -> [RegzaChannel] {
        let items = stations.enumerated().map { index, station in
            """
            {"channel":"\(code(1, index + 1))","channel_number":\(station.number),"rcu_channel_number":\(index + 1),\
            "name":"\(station.name)","ex_channel_number":"\(station.band)_\(station.number)","show_setting":"SHOW_REPRESENT"}
            """
        }
        return (try? JSONDecoder().decode([RegzaChannel].self, from: Data("[\(items.joined(separator: ","))]".utf8))) ?? []
    }

    static func programs(now: Date = Date()) -> [MirakurunProgram] {
        let titles = [
            "夜のニュース", "天気予報", "クイズ王決定戦", "ドラマ　港の灯", "世界の車窓",
            "アニメ　星の子", "スポーツまとめ", "映画　風の街", "料理のじかん", "ドキュメント　森",
        ]
        // 架空の出演者 (検索で「〇〇 が出演」と出るのを確かめる)
        let casts = ["見本太郎，例示花子", "", "試験一郎", "", "例示花子，仮名次郎", ""]
        let start = (Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now).addingTimeInterval(-3600)
        var items: [String] = []
        for (index, _) in stations.enumerated() {
            var time = start.addingTimeInterval(TimeInterval(index % 3) * -900)
            var event = 1
            while time < start.addingTimeInterval(26 * 3600) {
                let minutes = [30, 60, 45, 90, 15, 60][(event + index) % 6]
                let title = titles[(event * 3 + index) % titles.count]
                let cast = casts[(event * 5 + index) % casts.count]
                items.append("""
                    {"id":\(1 * 10_000_000_000 + (index + 1) * 100_000 + event),"eventId":\(event),"networkId":1,\
                    "serviceId":\(index + 1),"startAt":\(Int(time.timeIntervalSince1970 * 1000)),"duration":\(minutes * 60_000),\
                    "name":"\(title)","description":"見本の番組です。","extended":{"番組内容":"見本の番組の内容です。"\(cast.isEmpty ? "" : ",\"出演者\":\"\(cast)\"")},\
                    "genres":[{"lv1":\((event + index) % 12)}]}
                    """)
                time = time.addingTimeInterval(TimeInterval(minutes * 60))
                event += 1
            }
        }
        return (try? JSONDecoder().decode([MirakurunProgram].self, from: Data("[\(items.joined(separator: ","))]".utf8))) ?? []
    }

    static func reservations(programs: [MirakurunProgram], now: Date = Date()) -> [RegzaReservation] {
        let upcoming = programs.filter { $0.start > now }.prefix(40)
        let picked = [upcoming.dropFirst(3).first, upcoming.dropFirst(17).first].compactMap { $0 }
        let items = picked.enumerated().map { index, program in
            """
            {"rsv_id":"\(index + 1)","title":"\(program.name)","channel":"\(program.channelCode)",\
            "epg_content_id":"\(program.epgContentID)","start_time":\(Int(program.start.timeIntervalSince1970)),\
            "duration":\(Int(program.end.timeIntervalSince(program.start))),"repeat":"\(index == 0 ? "weekly" : "none")",\
            "series_rec":"\(index == 0)"}
            """
        }
        return (try? JSONDecoder().decode([RegzaReservation].self, from: Data("[\(items.joined(separator: ","))]".utf8))) ?? []
    }
}
#endif
