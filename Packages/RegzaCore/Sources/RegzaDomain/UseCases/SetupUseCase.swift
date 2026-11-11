import Foundation

/// 設定: テレビや録画サーバーを探す・テレビへの PIN 登録・録画サーバーとの連携
@MainActor
public protocol SetupUseCaseProtocol: AnyObject {
    /// 同じネットワークのテレビを、見つかった順に返す (UI の型)
    func findTVs() -> AsyncStream<DeviceItem>

    /// テレビに PIN を表示させてから確定するまでの 1 回の登録
    func pairing(host: String, user: String) -> any PairingRegistration

    func findGuideServers() async -> [String]

    func findStreamServers() async -> [String]

    /// Mirakurun と同じサーバーで EPGStation が動いていれば、そのアドレスを返す
    func streamServer(sameAs guideServer: String) async -> String?

    /// 保存済みの連携しているアドレス
    var linkedGuideHost: String { get }

    var linkedStreamHost: String { get }

    /// 録画サーバーのアドレスを保存する
    func saveServers(guideHost: String, streamHost: String) async

    /// 番組表 (Mirakurun) との連携をやめる。EPGStation は Mirakurun から放送を受け取るので、ライブ視聴の連携も一緒にやめる
    func unlinkGuide() async

    /// ライブ視聴 (EPGStation) との連携をやめる
    func unlinkStream()
}

/// 設定: テレビや録画サーバーを探す・テレビへの PIN 登録・録画サーバーとの連携
@MainActor
public final class SetupUseCase: SetupUseCaseProtocol {
    private let devices: any DeviceRepositoryProtocol
    private let guide: any GuideRepositoryProtocol
    private let stream: any StreamRepositoryProtocol
    private let onGuideHostChange: @MainActor (String) async -> Void

    public init(
        devices: any DeviceRepositoryProtocol, guide: any GuideRepositoryProtocol, stream: any StreamRepositoryProtocol,
        onGuideHostChange: @escaping @MainActor (String) async -> Void = { _ in }
    ) {
        self.devices = devices
        self.guide = guide
        self.stream = stream
        self.onGuideHostChange = onGuideHostChange
    }

    /// 同じネットワークのテレビを、見つかった順に返す (UI の型)
    public func findTVs() -> AsyncStream<DeviceItem> {
        let found = devices.devices()
        return AsyncStream { continuation in
            let task = Task {
                for await device in found {
                    continuation.yield(DeviceItem(host: device.host, name: device.name, supportsPIN: device.supportsPIN))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// テレビに PIN を表示させてから確定するまでの 1 回の登録
    public func pairing(host: String, user: String) -> any PairingRegistration {
        PairingUseCaseSession(session: devices.pairing(host: host, user: user))
    }

    public func findGuideServers() async -> [String] {
        await devices.findGuideServers()
    }

    public func findStreamServers() async -> [String] {
        await devices.findStreamServers()
    }

    /// Mirakurun と同じサーバーで EPGStation が動いていれば、そのアドレスを返す
    public func streamServer(sameAs guideServer: String) async -> String? {
        guard !guideServer.isEmpty, await devices.isStreamServer(host: guideServer) else { return nil }
        return guideServer
    }

    /// 保存済みの連携しているアドレス
    public var linkedGuideHost: String { guide.guideHost }
    public var linkedStreamHost: String { stream.streamHost }

    /// 録画サーバーのアドレスを保存する
    public func saveServers(guideHost: String, streamHost: String) async {
        let previousHost = guide.guideHost
        await guide.saveGuideHost(guideHost)
        if guide.guideHost != previousHost { await onGuideHostChange(guide.guideHost) }
        stream.saveStreamHost(streamHost)
    }

    /// 番組表 (Mirakurun) との連携をやめる。EPGStation は Mirakurun から放送を受け取るので、ライブ視聴の連携も一緒にやめる
    public func unlinkGuide() async {
        await saveServers(guideHost: "", streamHost: "")
    }

    /// ライブ視聴 (EPGStation) との連携をやめる
    public func unlinkStream() {
        stream.saveStreamHost("")
    }
}

/// 登録処理が画面へ公開する契約。資格情報は SharedModel で返す。
public protocol PairingRegistration: Sendable {
    func start() async throws
    func confirm(pin: String) async throws -> ConnectionItem
    func cancel() async
}

private struct PairingUseCaseSession: PairingRegistration {
    let session: any PairingSession
    func start() async throws { try await session.start() }
    func confirm(pin: String) async throws -> ConnectionItem {
        UseCaseModelMapper.connection(try await session.confirm(pin: pin))
    }
    func cancel() async { await session.cancel() }
}
