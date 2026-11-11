import Foundation
import MirakurunAPI
import RegzaDomain

enum MirakurunProgramMapper {
    /// 生成 DTO を直接 Domain に変換する。番組表全体を JSON に再エンコードしない。
    static func program(_ source: MirakurunAPI.Components.Schemas.Program) throws -> MirakurunProgram {
        let extended = try (source.extended?.value ?? [:]).map { key, value in
            guard let text = value as? String else { throw RegzaError.unsupported }
            return MirakurunProgram.Extended(title: key, text: text)
        }
        let genres = try (source.genres ?? []).map { genre in
            guard let value = genre.lv1 else { throw RegzaError.unsupported }
            return value
        }
        let startAt = Double(source.startAt)
        let duration = Double(source.duration ?? 0)
        return MirakurunProgram(
            id: source.id, networkId: source.networkId, serviceId: source.serviceId,
            eventId: source.eventId ?? source.id % 100_000,
            start: Date(timeIntervalSince1970: startAt / 1000), end: Date(timeIntervalSince1970: (startAt + duration) / 1000),
            name: source.name ?? "", description: source.description ?? "", extended: extended, genres: genres
        )
    }
}
