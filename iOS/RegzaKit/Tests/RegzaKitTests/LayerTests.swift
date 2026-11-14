import Foundation
import Testing

/// 画面 (UI) と Live Activity (LiveActivity) が、ViewModel と UI の型 (RegzaPresentation) より下の層
/// (Domain・通信・組み立て) を使っていないことを確かめる。どちらも ViewModel の state を読み、Action を送るだけにする。
/// RegzaPresentation は Domain を外に見せないが、SwiftPM は依存の先のモジュールを import すること自体は止めないので、
/// import を見て止める
@Suite struct LayerTests {
    /// 画面が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型・色・文言・Live Activity のスイッチ)
    static let viewImports: Set<String> = [
        "SwiftUI", "Foundation", "Observation", "AVKit", "UIKit",
        "RegzaPresentation", "Design", "Localization", "LiveActivity",
    ]

    /// Live Activity が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型)
    static let liveActivityImports: Set<String> = [
        "Foundation", "Observation", "ActivityKit", "BackgroundTasks",
        "RegzaPresentation",
    ]

    @Test func viewsImportOnlyPresentation() throws {
        try Self.check("UI", allowed: Self.viewImports)
    }

    @Test func liveActivityImportsOnlyPresentation() throws {
        try Self.check("LiveActivity", allowed: Self.liveActivityImports)
    }

    static func check(_ module: String, allowed: Set<String>) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/\(module)")
        let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") {
                // `import X`・`@testable import X`・`public import X` などの X を取り出す
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(of: "import"), index + 1 < words.count,
                    words[..<index].allSatisfy({
                        $0.hasPrefix("@") || ["public", "package", "internal", "private", "fileprivate"].contains($0)
                    })
                else { continue }
                let imported = String(words[index + 1].split(separator: ".").first ?? "")
                #expect(
                    allowed.contains(imported),
                    "\(module) の \(file.lastPathComponent) が \(imported) を import している (ViewModel の state と Action だけを使う)")
            }
        }
    }
}
