import Foundation
public import Observation
public import PresentationCore
package import RegzaDomain

/// 1 チャンネルの番組表の画面の ViewModel。放送中の番組から日ごとに並べる
@MainActor
@Observable
public final class ProgramListViewModel {
    private let guideUseCase: any GuideUseCaseProtocol
    private let recordingUseCase: any RecordingUseCaseProtocol
    package let channel: ChannelItem

    package init(guideUseCase: any GuideUseCaseProtocol, recordingUseCase: any RecordingUseCaseProtocol, channel: ChannelItem) {
        self.guideUseCase = guideUseCase
        self.recordingUseCase = recordingUseCase
        self.channel = channel
    }

    /// 画面に出すもの
    public typealias State = ProgramListState

    /// 画面からの操作
    public typealias Action = ProgramListAction

    private var programs: [ProgramItem]?
    private var loadError: RegzaError?
    private var isLoading = false
    @ObservationIgnored private let work = Work()

    public var state: State {
        State(
            channelCode: channel.code,
            channelName: channel.name,
            days: programs.map { guideUseCase.days($0) },
            isLoading: isLoading,
            loadErrorMessage: programs == nil ? loadError.map { ErrorMessage.text($0) } : nil
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .appear:
            work.run {
                if self.programs == nil { await self.load() }
                // 予約の印を付けるための下準備。読めなくても、番組はそのまま出す
                if self.recordingUseCase.reservations.isEmpty { try? await self.recordingUseCase.loadReservations() }
            }
        case .reload: work.run { await self.load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            programs = try await guideUseCase.programs(for: channel)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}

extension ProgramListViewModel: IntrospectableActions {
    public var introspectionName: String { "programList" }
    public var isBusy: Bool { work.isBusy }

    public var introspectionTable: [IntrospectionAction<Action>] {
        [
            IntrospectionAction("appear", "画面を開いたときと同じく読み込む", .appear),
            IntrospectionAction("reload", "番組を読み直す", .reload),
        ]
    }
}
