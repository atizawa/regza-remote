import Foundation
import Testing

/// 画面 (RegzaRemoteViews) が、ViewModel と UI の型 (RegzaPresentation) より下の層を使っていないことを確かめる。
/// RegzaPresentation は Domain を外に見せないが、SwiftPM は依存の先のモジュールを import すること自体は止めないので、
/// import を見て止める
@Suite struct LayerTests {
    /// 画面が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型・Live Activity のスイッチ)
    static let allowedImports: Set<String> = [
        "SwiftUI", "Foundation", "Observation", "AVKit", "UIKit",
        "RegzaPresentation", "RegzaLiveActivity",
    ]

    static var viewsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/RegzaRemoteViews")
    }

    @Test func viewsImportOnlyPresentation() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.viewsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") {
                // `import X`・`@testable import X`・`public import X` などの X を取り出す
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(of: "import"), index + 1 < words.count,
                      words[..<index].allSatisfy({ $0.hasPrefix("@") || ["public", "package", "internal", "private", "fileprivate"].contains($0) })
                else { continue }
                let module = String(words[index + 1].split(separator: ".").first ?? "")
                #expect(Self.allowedImports.contains(module), "\(file.lastPathComponent) が \(module) を import している (画面は RegzaPresentation だけを使う)")
            }
        }
    }
}
