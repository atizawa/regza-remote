import Foundation
import Testing
@testable import RegzaDomain
@testable import RegzaInfrastructure

@Suite struct SwitchingTests {
    /// テレビに送るキーコード (キーの値は名前で、コードは Infrastructure が持つ)
    @Test func keyCodes() {
        #expect(RegzaKey.power.rawValue == "power")
        #expect(RegzaKey.power.code == "40BF12")
        #expect(RegzaKey.num10.code == "40BF0A")
        #expect(RegzaKey.subtitle.code == "43BC52")
        // どのキーもコードが重ならない
        #expect(Set(RegzaKey.allCases.map(\.code)).count == RegzaKey.allCases.count)
    }

    @Test func switchingKeys() {
        #expect(RegzaKey.enter.mayStartContentSwitch)
        #expect(RegzaKey.play.mayStartContentSwitch)
        #expect(!RegzaKey.volumeUp.mayStartContentSwitch)
        #expect(!RegzaKey.num1.mayStartContentSwitch)
    }

    @Test func probeIgnoresPlaybackPosition() {
        let playing = RegzaStatus(text: "action=2\ntitle_no=100\ntitle_name=テスト\nch_code=G00000001\ntitle_time=10")
        var later = playing
        later.titleTime = 12
        #expect(RegzaRemote.Probe(playing) == RegzaRemote.Probe(later))
        // 切り替わりの最中は値が空になる
        let switching = RegzaStatus(text: "action=0\ntitle_no=0\ntitle_name=\nch_code=G00000000\ntitle_time=0")
        #expect(RegzaRemote.Probe(playing) != RegzaRemote.Probe(switching))
    }

    @Test func advancesWithoutPlayStatus() {
        let start = Date(timeIntervalSince1970: 1_000)
        let broadcast = RegzaNowPlaying(kind: .broadcast, position: 100, duration: 600, isAdvancing: true, updatedAt: start)
        let movedOn = RegzaRemote.advanced(broadcast, with: RegzaStatus(), now: start.addingTimeInterval(30))
        #expect(movedOn.position == 130)
        #expect(movedOn.updatedAt == start.addingTimeInterval(30))

        let recorded = RegzaNowPlaying(kind: .recorded, title: "テスト", position: 50, duration: 600, isAdvancing: false, updatedAt: start)
        let status = RegzaStatus(text: "action=2\ntitle_name=テスト\ntotal_time=600\ntitle_time=52")
        let played = RegzaRemote.advanced(recorded, with: status, now: start.addingTimeInterval(2))
        #expect(played.position == 52)
        #expect(played.isAdvancing)
    }
}
