import Foundation

/// リモコンのキーについての決まり (キーそのものは UI の型 RegzaSharedModels の RegzaKey)
extension RegzaKey {
    /// テレビの映像が切り替わることがあるキー (録画の再生を始める・止める、一覧を閉じるなど)。
    /// 送った直後は視聴状況を問い合わせない (`RegzaRemote.switchingQuietPeriod`)
    public var mayStartContentSwitch: Bool {
        switch self {
        case .enter, .play, .stop, .back, .exit, .jumpToStart, .timeShift, .recordedList: true
        default: false
        }
    }
}
