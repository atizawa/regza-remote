import Foundation

extension BroadcastBand {
    /// 出す放送の種類。選んでいればそれ、なければいま見ている放送の種類、それもなければ最初のもの
    public static func preferred(
        among bands: [BroadcastBand], selected: BroadcastBand?, nowPlaying: BroadcastBand?
    ) -> BroadcastBand? {
        if let selected, bands.contains(selected) { return selected }
        if let nowPlaying, bands.contains(nowPlaying) { return nowPlaying }
        return bands.first
    }
}
