public import Foundation
public import Observation
package import RegzaDomain

/// 1 チャンネルの番組表の画面の ViewModel。放送中の番組から日ごとに並べる
@MainActor
@Observable
public final class ProgramListViewModel {
    package let guide: any GuideUseCaseProtocol
    package let recording: any RecordingUseCaseProtocol
    package let channel: RegzaChannel

    package init(guide: any GuideUseCaseProtocol, recording: any RecordingUseCaseProtocol, channel: RegzaChannel) {
        self.guide = guide
        self.recording = recording
        self.channel = channel
    }

    /// 画面に出すもの
    public typealias State = ProgramListState

    /// 画面からの操作
    public typealias Action = ProgramListAction

    private var programs: [MirakurunProgram]?
    private var loadError: RegzaError?
    @ObservationIgnored private let work = Work()

    public var state: State {
        State(
            channelCode: channel.code,
            channelName: channel.name,
            days: programs.map { guide.days($0) },
            loadErrorMessage: programs == nil ? loadError?.localizedDescription : nil
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                if self.programs == nil { await self.load() }
                if self.recording.reservations.isEmpty { try? await self.recording.loadReservations() }
            }
        case .reload: work.run { await self.load() }
        }
    }

    private func load() async {
        do {
            programs = try await guide.programs(for: channel)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

extension ProgramListViewModel: IntrospectableActions {
    public var introspectionName: String { "programList" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionActions: [ActionDescription] {
        [ActionDescription("appear", "画面を開いたときと同じく読み込む"), ActionDescription("reload", "番組を読み直す")]
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        switch name {
        case "appear": return .appear
        case "reload": return .reload
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
