#if !REGZA_FAKES_DISABLED
import Foundation
import RegzaDomain

/// 偽物のテレビと録画サーバーが共通に持つ、架空の局と番組。実在の機器・局の情報は入れない
public struct FakeCatalog: Sendable {
    public struct Station: Sendable, Equatable {
        public var networkID: Int
        public var serviceID: Int
        public var name: String
        /// 3 桁のチャンネル番号
        public var number: Int
        /// リモコンの番号ボタンの番号
        public var remoteNumber: Int
        /// `DUV` (地デジ)・`DBS` (BS)・`DCS` (CS)
        public var band: String
        /// 同じ局のサブチャンネルのうちの代表か
        public var isRepresentative: Bool

        public var code: String { BroadcastID.channelCode(networkId: networkID, serviceId: serviceID) }
    }

    public struct Program: Sendable, Equatable {
        public var networkID: Int
        public var serviceID: Int
        public var eventID: Int
        public var start: Date
        /// 秒
        public var duration: Int
        public var name: String
        public var description: String
        public var cast: String?
        /// ARIB のジャンルの大分類
        public var genre: Int

        /// Mirakurun の番組 ID
        public var id: Int { networkID * 10_000_000_000 + serviceID * 100_000 + eventID }
        public var channelCode: String { BroadcastID.channelCode(networkId: networkID, serviceId: serviceID) }
        public var epgContentID: String { BroadcastID.epgContentID(networkId: networkID, serviceId: serviceID, eventId: eventID) }
        public var end: Date { start.addingTimeInterval(TimeInterval(duration)) }
    }

    /// 録画番組
    public struct Recording: Sendable, Equatable {
        public var title: String
        public var channelName: String
        /// 秒
        public var duration: Int
        public var chapterName: String
    }

    public var stations: [Station]
    public var programs: [Program]
    public var recording: Recording

    public func station(code: String) -> Station? {
        stations.first { $0.code == code }
    }

    public func programs(code: String) -> [Program] {
        programs.filter { $0.channelCode == code }
    }

    public func program(epgContentID: String) -> Program? {
        programs.first { $0.epgContentID.caseInsensitiveCompare(epgContentID) == .orderedSame }
    }

    public func onAir(code: String, at now: Date) -> Program? {
        programs(code: code).first { $0.start <= now && now < $0.end }
    }

    /// 地デジ 2 局と BS 1 局。番組表は地デジの 2 局に、今の正時の 1 時間前から 2 日分、1 時間ずつ並べる
    public static func standard(now: Date = Date()) -> FakeCatalog {
        let stations = [
            Station(networkID: 0, serviceID: 1, name: "テスト局１", number: 11, remoteNumber: 1, band: "DUV", isRepresentative: true),
            Station(networkID: 0, serviceID: 2, name: "テスト局２", number: 21, remoteNumber: 2, band: "DUV", isRepresentative: true),
            Station(networkID: 4, serviceID: 1, name: "テストBS", number: 181, remoteNumber: 1, band: "DBS", isRepresentative: false),
        ]
        let names = ["見本の朝の便り", "見本の散歩", "見本の料理教室", "見本の劇場", "見本の天気"]
        let casts = ["見本太郎，例示花子", nil, "試験一郎"]
        let hour = (Int(now.timeIntervalSince1970) / 3600 - 1) * 3600
        var programs: [Program] = []
        for station in stations where station.band == "DUV" {
            for index in 0..<48 {
                programs.append(
                    Program(
                        networkID: station.networkID, serviceID: station.serviceID, eventID: index + 1,
                        start: Date(timeIntervalSince1970: TimeInterval(hour + index * 3600)), duration: 3600,
                        name: "\(names[(index + station.serviceID) % names.count]) 第\(index + 1)回",
                        description: "見本の番組です。", cast: casts[(index + station.serviceID) % casts.count],
                        genre: (index + station.serviceID) % 12))
            }
        }
        let recording = Recording(title: "見本の録画番組", channelName: "テスト局１", duration: 3240, chapterName: "見本のチャプター")
        return FakeCatalog(stations: stations, programs: programs, recording: recording)
    }
}
#endif
