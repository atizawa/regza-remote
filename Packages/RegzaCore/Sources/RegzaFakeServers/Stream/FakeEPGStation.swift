import EPGStationAPI
import Foundation
import RegzaInfrastructure

/// 偽物の EPGStation。配信を頼まれると番号を返し、すぐ再生できるプレイリストを出す (映像そのものは出さない)
struct FakeEPGStation {
    typealias Schemas = EPGStationAPI.Components.Schemas

    private(set) var streams: [Int] = []
    private var nextStreamID = 1

    mutating func respond(to request: FakeRequest) -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/api/version"):
            return FakeResponse.json(Schemas.Version(version: "2.10.0"))
        case ("GET", "/api/streams"):
            return FakeResponse.json(Schemas.StreamInfo(items: streams.map { Schemas.StreamInfoItem(isEnable: true, streamId: $0) }))
        case ("GET", _) where request.pathParameter(prefix: "/api/streams/live/", suffix: "/hls") != nil:
            let id = nextStreamID
            nextStreamID += 1
            streams.append(id)
            return FakeResponse.json(Schemas.StartStreamInfo(streamId: id))
        case ("GET", _):
            guard let id = request.pathParameter(prefix: "/streamfiles/stream", suffix: ".m3u8").flatMap(Int.init), streams.contains(id)
            else { return FakeResponse.notFound }
            return FakeResponse.text("#EXTM3U\nsegment0.ts\n")
        case ("PUT", _):
            guard let id = request.pathParameter(prefix: "/api/streams/", suffix: "/keep").flatMap(Int.init), streams.contains(id)
            else { return FakeResponse.notFound }
            return FakeResponse.empty()
        case ("DELETE", _):
            guard let id = request.pathParameter(prefix: "/api/streams/").flatMap(Int.init), streams.contains(id)
            else { return FakeResponse.notFound }
            streams.removeAll { $0 == id }
            return FakeResponse.empty()
        default:
            return FakeResponse.notFound
        }
    }
}
