#if !REGZA_FAKES_DISABLED
import Foundation
import MirakurunAPI
import OpenAPIRuntime
import RegzaInfrastructure

/// 偽物の Mirakurun。架空の番組表を返す
struct FakeMirakurun {
    typealias Schemas = MirakurunAPI.Components.Schemas

    let catalog: FakeCatalog

    func respond(to request: FakeRequest, now: Date) -> HTTPResponse {
        guard request.method == "GET" else { return FakeResponse.notFound }
        switch request.path {
        case "/api/version":
            return FakeResponse.json(Schemas.Version(current: "3.9.0", latest: "3.9.0"))
        case "/api/programs":
            let networkID = request.query["networkId"].flatMap(Int.init)
            let serviceID = request.query["serviceId"].flatMap(Int.init)
            let programs = catalog.programs.filter {
                (networkID == nil || $0.networkID == networkID) && (serviceID == nil || $0.serviceID == serviceID)
            }
            return FakeResponse.json(programs.map(Self.program))
        default:
            guard let id = request.pathParameter(prefix: "/api/programs/").flatMap(Int.init),
                let program = catalog.programs.first(where: { $0.id == id })
            else { return FakeResponse.notFound }
            return FakeResponse.json(Self.program(program))
        }
    }

    private static func program(_ program: FakeCatalog.Program) -> Schemas.Program {
        var extended = ["番組内容": "見本の番組の内容です。"]
        if let cast = program.cast { extended["出演者"] = cast }
        return Schemas.Program(
            description: program.description, duration: program.duration * 1000, eventId: program.eventID,
            extended: try? OpenAPIObjectContainer(unvalidatedValue: extended), genres: [Schemas.ProgramGenre(lv1: program.genre)],
            id: program.id, name: program.name, networkId: program.networkID, serviceId: program.serviceID,
            startAt: Int(program.start.timeIntervalSince1970 * 1000))
    }
}
#endif
