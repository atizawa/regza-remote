import Foundation

/// テレビの録画予約: 一覧・予約・取り消し
@MainActor
public protocol RecordingUseCaseProtocol: AnyObject {
    /// 録画予約。予定のあるものを先に、時刻順に並べる
    var reservations: [RegzaReservation] { get }

    /// 一覧に出す予約 (UI の型)。チャンネルの名前は、テレビに登録されているチャンネルから引く
    func items(channels: [RegzaChannel], now: Date) -> [ReservationItem]

    func loadReservations() async throws(RegzaError)

    /// その番組の予約。なければ nil
    func reservation(for program: MirakurunProgram) -> RegzaReservation?

    func isReserved(_ program: MirakurunProgram) -> Bool

    /// 番組表の番組を録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    func reserve(_ program: MirakurunProgram, series: Bool) async throws(RegzaError)

    func cancel(_ reservation: RegzaReservation) async throws(RegzaError)

    /// 一覧の予約を取り消す (UI の型の id から)
    func cancel(id: String) async throws(RegzaError)
}

extension RecordingUseCaseProtocol {
    public func items(channels: [RegzaChannel]) -> [ReservationItem] {
        items(channels: channels, now: Date())
    }

    public func reserve(_ program: MirakurunProgram) async throws(RegzaError) {
        try await reserve(program, series: false)
    }
}

/// テレビの録画予約: 一覧・予約・取り消し
@MainActor
public final class RecordingUseCase: RecordingUseCaseProtocol {
    private let recording: any RecordingRepositoryProtocol

    public init(recording: any RecordingRepositoryProtocol) {
        self.recording = recording
    }

    /// 録画予約。予定のあるものを先に、時刻順に並べる
    public var reservations: [RegzaReservation] { recording.reservations }

    /// 一覧に出す予約 (UI の型)。チャンネルの名前は、テレビに登録されているチャンネルから引く
    public func items(channels: [RegzaChannel], now: Date = Date()) -> [ReservationItem] {
        reservations.map { reservation in
            let isScheduled = reservation.isScheduled(now: now)
            return ReservationItem(
                id: reservation.id,
                title: reservation.title,
                timeText: DisplayText.range(reservation.start, reservation.end),
                repeatLabel: reservation.repeatLabel,
                isSeries: reservation.isSeries,
                channelName: channels.first { $0.code == reservation.channelCode }?.name,
                isRecording: isScheduled && reservation.start <= now,
                isScheduled: isScheduled
            )
        }
    }

    public func loadReservations() async throws(RegzaError) {
        try await recording.loadReservations()
    }

    /// その番組の予約。なければ nil
    public func reservation(for program: MirakurunProgram) -> RegzaReservation? {
        recording.reservation(for: program)
    }

    public func isReserved(_ program: MirakurunProgram) -> Bool {
        recording.isReserved(program)
    }

    /// 番組表の番組を録画予約する。`series` なら連ドラ予約 (次の回以降も録画する)
    public func reserve(_ program: MirakurunProgram, series: Bool = false) async throws(RegzaError) {
        try await recording.reserve(program, series: series)
    }

    public func cancel(_ reservation: RegzaReservation) async throws(RegzaError) {
        try await recording.cancel(reservation)
    }

    /// 一覧の予約を取り消す (UI の型の id から)
    public func cancel(id: String) async throws(RegzaError) {
        guard let reservation = reservations.first(where: { $0.id == id }) else { return }
        try await recording.cancel(reservation)
    }
}
