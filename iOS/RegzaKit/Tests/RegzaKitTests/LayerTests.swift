import Foundation
import Testing

/// 画面 (機能のモジュール・共通の部品・組み立て) と Live Activity (LiveActivity) が、ViewModel と UI の型 (RegzaPresentation) より
/// 下の層 (Domain・通信・組み立て) を使っていないことを確かめる。どれも ViewModel の state を読み、Action を送るだけにする。
/// 機能のモジュール (<機能>Feature) は、ほかの機能を読み込まない (ほかの機能の画面は、組み立て (UI) が環境値で渡す)。
/// RegzaPresentation は Domain を外に見せないが、SwiftPM は依存の先のモジュールを import すること自体は止めないので、
/// import を見て止める。画面のプレビュー (`#if DEBUG` の中) だけは、偽物のテレビ・録画サーバーを使ってよい
@Suite struct LayerTests {
    /// プレビューの中でだけ読み込んでよいモジュール
    static let previewImports: Set<String> = ["RegzaFakeServers"]

    /// 画面が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型・色・文言・Live Activity のスイッチ)
    static let viewImports: Set<String> = [
        "SwiftUI", "Foundation", "Observation", "AVKit", "UIKit",
        "RegzaPresentation", "Design", "Localization", "LiveActivity",
    ]

    /// Live Activity が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型・文言)
    static let liveActivityImports: Set<String> = [
        "Foundation", "Observation", "ActivityKit", "BackgroundTasks",
        "RegzaPresentation", "Localization",
    ]

    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// 機能のモジュール (Sources/Features の下のフォルダ)
    static let features: [String] = {
        let directory = package.appendingPathComponent("Sources/Features").path
        return ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }()

    @Test func commonPartsImportOnlyPresentation() throws {
        try Self.check("UICommon", allowed: Self.viewImports)
    }

    @Test(arguments: features)
    func featuresImportOnlyPresentationAndCommonParts(feature: String) throws {
        try Self.check("Features/\(feature)", allowed: Self.viewImports.union(["UICommon"]))
    }

    @Test func compositionImportsFeatures() throws {
        try Self.check("UI", allowed: Self.viewImports.union(["UICommon"]).union(Self.features))
    }

    /// Sources/Features のフォルダと、Package.swift の機能の一覧 (features) が同じこと (フォルダだけ足しても、モジュールにならない)
    @Test func featureFoldersMatchPackage() throws {
        let manifest = try String(contentsOf: Self.package.appendingPathComponent("Package.swift"), encoding: .utf8)
        let list = try #require(manifest.range(of: #"let features = \[[^\]]*\]"#, options: .regularExpression))
        let declared = manifest[list].split(separator: "\"").enumerated().filter { $0.offset % 2 == 1 }.map { String($0.element) }
        #expect(!Self.features.isEmpty)
        #expect(declared.sorted() == Self.features)
    }

    @Test func liveActivityImportsOnlyPresentation() throws {
        try Self.check("LiveActivity", allowed: Self.liveActivityImports)
    }

    /// `DEBUG`、または `DEBUG` を && でつないだ条件 (`os(iOS) && DEBUG` など) なら、Debug のビルドでだけ入る
    static func requiresDebug(_ condition: String) -> Bool {
        !condition.contains("||") && condition.components(separatedBy: "&&").contains { $0.trimmingCharacters(in: .whitespaces) == "DEBUG" }
    }

    @Test func debugConditions() {
        #expect(Self.requiresDebug("DEBUG"))
        #expect(Self.requiresDebug("os(iOS) && DEBUG"))
        #expect(!Self.requiresDebug("!DEBUG"))
        #expect(!Self.requiresDebug("DEBUG || os(macOS)"))
        #expect(!Self.requiresDebug("os(iOS)"))
    }

    static func check(_ module: String, allowed: Set<String>) throws {
        let directory = package.appendingPathComponent("Sources/\(module)")
        let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            // `#if` ごとに、いまの分かれ道が Debug のビルドでだけ入る場所かどうか
            var conditions: [Bool] = []
            for line in source.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#if ") {
                    conditions.append(Self.requiresDebug(String(trimmed.dropFirst(4))))
                } else if trimmed.hasPrefix("#elseif") || trimmed.hasPrefix("#else") {
                    // DEBUG の条件の反対側や別の条件は、リリースのビルドでも入りうる
                    if !conditions.isEmpty { conditions[conditions.count - 1] = false }
                } else if trimmed.hasPrefix("#endif") {
                    _ = conditions.popLast()
                }
                // `import X`・`@testable import X`・`public import X` などの X を取り出す
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(of: "import"), index + 1 < words.count,
                    words[..<index].allSatisfy({
                        $0.hasPrefix("@") || ["public", "package", "internal", "private", "fileprivate"].contains($0)
                    })
                else { continue }
                let imported = String(words[index + 1].split(separator: ".").first ?? "")
                #expect(
                    allowed.contains(imported) || (conditions.contains(true) && previewImports.contains(imported)),
                    "\(module) の \(file.lastPathComponent) が \(imported) を import している (ViewModel の state と Action だけを使う)")
            }
        }
    }
}
