import Foundation

extension Sequence where Element == ChannelItem {
    /// 同じ放送局のサブチャンネル (リモコン番号が同じチャンネル) をまとめる。番組表とチャンネル一覧で同じ局の並びにする。
    /// リモコン番号ごとに代表 (`SHOW_REPRESENT` の印のあるもの、なければ最初のもの) を残し、
    /// サブチャンネルは `showsSubchannel` が true を返したものだけ残す。リモコン番号のないチャンネルはそのまま残す。並びは変えない
    public func groupingSubchannels(
        showing showsSubchannel: (_ subchannel: ChannelItem, _ representative: ChannelItem) -> Bool = { _, _ in false }
    ) -> [ChannelItem] {
        let channels = Array(self)
        var representatives: [Int: ChannelItem] = [:]
        for channel in channels.filter(\.isRepresentative) + channels.filter({ !$0.isRepresentative })
        where channel.remoteNumber > 0 && representatives[channel.remoteNumber] == nil {
            representatives[channel.remoteNumber] = channel
        }
        return channels.filter { channel in
            guard channel.remoteNumber > 0, let representative = representatives[channel.remoteNumber],
                representative != channel
            else { return true }
            return showsSubchannel(channel, representative)
        }
    }
}
