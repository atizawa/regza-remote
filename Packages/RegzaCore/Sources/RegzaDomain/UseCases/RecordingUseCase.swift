import Foundation

@MainActor
public protocol RecordingUseCaseProtocol: AnyObject {
    var reservations: [ReservationItem] { get }
    func items(channels: [ChannelItem], now: Date) -> [ReservationItem]
    func loadReservations() async throws(RegzaError)
    func reservation(for program: ProgramItem) -> ReservationItem?
    func isReserved(_ program: ProgramItem) -> Bool
    func reserve(_ program: ProgramItem, series: Bool) async throws(RegzaError)
    func cancel(_ reservation: ReservationItem) async throws(RegzaError)
    func cancel(id: String) async throws(RegzaError)
}

extension RecordingUseCaseProtocol {
    public func items(channels: [ChannelItem]) -> [ReservationItem] {
        items(channels: channels, now: Date())
    }

    public func reserve(_ program: ProgramItem) async throws(RegzaError) {
        try await reserve(program, series: false)
    }
}

/// 操作対象は番組の ID で Repository から解決し、画面から Data を受け取らない。
@MainActor
public final class RecordingUseCase: RecordingUseCaseProtocol {
    private let recordingRepository: any RecordingRepositoryProtocol
    private let guideRepository: any GuideRepositoryProtocol

    public init(recordingRepository: any RecordingRepositoryProtocol, guideRepository: any GuideRepositoryProtocol) {
        self.recordingRepository = recordingRepository
        self.guideRepository = guideRepository
    }

    public var reservations: [ReservationItem] {
        recordingRepository.reservations.map { UseCaseModelMapper.reservation($0, now: Date()) }
    }

    public func items(channels: [ChannelItem], now: Date = Date()) -> [ReservationItem] {
        recordingRepository.reservations.map { data in
            UseCaseModelMapper.reservation(data, channelName: channels.first { $0.code == data.channelCode }?.name, now: now)
        }
    }

    public func loadReservations() async throws(RegzaError) {
        try await recordingRepository.loadReservations()
    }

    public func reservation(for program: ProgramItem) -> ReservationItem? {
        guard let data = guideRepository.program(id: program.id, channelCode: program.channelCode),
            let reservation = recordingRepository.reservation(for: data)
        else { return nil }
        return UseCaseModelMapper.reservation(reservation, now: Date())
    }

    public func isReserved(_ program: ProgramItem) -> Bool {
        reservation(for: program) != nil
    }

    public func reserve(_ program: ProgramItem, series: Bool = false) async throws(RegzaError) {
        guard let data = guideRepository.program(id: program.id, channelCode: program.channelCode) else { throw .unsupported }
        try await recordingRepository.reserve(data, series: series)
    }

    public func cancel(_ reservation: ReservationItem) async throws(RegzaError) {
        try await cancel(id: reservation.id)
    }

    public func cancel(id: String) async throws(RegzaError) {
        guard let data = recordingRepository.reservations.first(where: { $0.id == id }) else { return }
        try await recordingRepository.cancel(data)
    }
}
