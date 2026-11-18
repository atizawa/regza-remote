#if os(iOS)
import SwiftUI

/// 共通のリモコン配色を SwiftUI の面・グラデーションとして使う。
public enum RemoteBody {
    public static let background = LinearGradient(
        colors: [DesignColors.remoteBackgroundStart, DesignColors.remoteBackgroundEnd],
        startPoint: .top, endPoint: .bottom
    )
    public static let grayKey = DesignColors.remoteGrayKey
    public static let panel = DesignColors.remotePanel
    public static let key = DesignColors.remoteKey
    public static let keyHighlight = LinearGradient(
        colors: [DesignColors.remoteHighlight, .clear], startPoint: .top, endPoint: .center
    )
    public static let edge = DesignColors.remoteEdge
    public static let ring = DesignColors.remoteRing
    public static let center = LinearGradient(
        colors: [DesignColors.remoteCenterStart, DesignColors.remoteCenterEnd],
        startPoint: .top, endPoint: .bottom
    )
    public static let power = DesignColors.remotePower
}
#endif
