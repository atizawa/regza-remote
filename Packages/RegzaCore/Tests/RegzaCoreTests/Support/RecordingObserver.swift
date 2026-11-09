import Foundation
@testable import RegzaCore
@testable import RegzaDomain

@MainActor
final class RecordingObserver: RemoteViewModelObserver {
    private(set) var events: [String] = []

    func remoteViewModel(_ model: RemoteViewModel, didUpdate nowPlaying: RegzaNowPlaying?, isConnected: Bool) async {
        events.append("update \(nowPlaying?.channelCode ?? "-") \(isConnected ? "connected" : "disconnected")")
    }

    func remoteViewModelDidTune(_ model: RemoteViewModel) async {
        events.append("tune")
    }
}
