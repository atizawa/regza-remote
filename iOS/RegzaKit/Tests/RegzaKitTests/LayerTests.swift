import Foundation
import Testing

/// iOS のモジュールが読み込むものを確かめる。
/// - 画面 (機能のモジュール・共通の部品・組み立て)、Live Activity、画面のない入口 (SystemActions・Shortcuts)、ウィジェットは、
///   プレゼンテーション層 (ViewModel と UI の型) より下の層 (Domain・通信・共有の組み立て) を使わない。どれも ViewModel の state を読み、Action を送るだけにする
/// - 機能の画面のモジュール (<機能>UI) は、共通 (PresentationCore) と自分の機能のプレゼンテーション (<機能>Presentation) だけを読み込み、
///   ほかの機能とアプリ全体 (AppPresentation) を読み込まない (ほかの画面へ移るときは共通の窓口 AppNavigator に頼み、
///   ほかの機能の画面は組み立て (AppUI) が出す)
/// - アプリの組み立て (AppServices) だけが、共有の組み立て (RegzaApp) と通信を使う。画面と画面のない入口は読み込まない
/// SwiftPM は依存の先のモジュールを import すること自体は止めないので、import を見て止める。
/// 画面のプレビュー (`#if DEBUG` の中) だけは、偽物のテレビ・録画サーバーと、それで組み立てたアプリ全体の ViewModel を使ってよい
@Suite struct LayerTests {
    /// プレビューの中でだけ読み込んでよいモジュール
    static let previewImports: Set<String> = ["RegzaFakeServers", "AppPresentation"]

    /// 画面が読み込んでよいモジュール (Apple のものと、共通のプレゼンテーション・色・文言・Live Activity のスイッチ)
    static let viewImports: Set<String> = [
        "SwiftUI", "Foundation", "Observation", "AVKit", "UIKit",
        "PresentationCore", "Design", "Localization", "LiveActivity",
    ]

    /// 機能の画面のモジュールが使う、その機能のプレゼンテーション (リモコンは共通のものだけを使う)
    static func presentation(of feature: String) -> Set<String> {
        feature == "RemoteUI" ? [] : [feature.replacingOccurrences(of: "UI", with: "Presentation")]
    }

    /// Live Activity が読み込んでよいモジュール (Apple のものと、ViewModel・UI の型・文言)
    static let liveActivityImports: Set<String> = [
        "Foundation", "Observation", "ActivityKit", "BackgroundTasks",
        "RegzaPresentation", "Localization",
    ]

    /// 画面のない入口 (ウィジェット・コントロールセンター・Live Activity のボタンからの操作) が読み込んでよいモジュール。
    /// 画面と同じく ViewModel の state と Action だけを使い、Domain・通信は読み込まない (AppContainer から ViewModel を受け取る)
    static let systemActionsImports: Set<String> = ["Foundation", "AppIntents", "RegzaPresentation", "AppServices"]

    /// Siri・ショートカットが読み込んでよいモジュール (画面のない入口と同じ決まりに、Live Activity と共有の文言を足したもの)
    static let shortcutsImports = systemActionsImports.union(["LiveActivity", "RegzaStrings"])

    /// ウィジェット (ホーム画面・Live Activity・コントロールセンターの表示) が読み込んでよいモジュール。
    /// 表示は ViewModel の state を使い、ボタンの操作は画面のない入口 (SystemActions) に任せる。アプリの組み立て (AppServices) は読み込まない
    static let widgetsImports: Set<String> = [
        "Foundation", "SwiftUI", "WidgetKit", "ActivityKit", "AppIntents",
        "RegzaPresentation", "Design", "Localization", "LiveActivity", "SystemActions",
    ]

    /// アプリの組み立て (AppContainer)・保存先・終了時の処理が読み込んでよいモジュール。
    /// 共有の組み立て (RegzaApp) と通信 (保存先の受け口) を使う唯一の場所で、画面と画面のない入口は読み込まない
    static let appServicesImports: Set<String> = [
        "Foundation", "Security", "RegzaApp", "RegzaInfrastructure", "LiveActivity", "Localization",
    ]

    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// 機能の画面のモジュール (Sources/UI の下の、共通 (UICommon) と組み立て (AppUI) 以外のフォルダ)
    static let features: [String] = {
        let directory = package.appendingPathComponent("Sources/UI").path
        return ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? [])
            .filter { !$0.hasPrefix(".") && !["UICommon", "AppUI"].contains($0) }.sorted()
    }()

    @Test func commonPartsImportOnlyPresentation() throws {
        try Self.check("UI/UICommon", allowed: Self.viewImports)
    }

    @Test(arguments: features)
    func featuresImportOnlyPresentationAndCommonParts(feature: String) throws {
        try Self.check("UI/\(feature)", allowed: Self.viewImports.union(["UICommon"]).union(Self.presentation(of: feature)))
    }

    @Test func compositionImportsFeatures() throws {
        try Self.check("UI/AppUI", allowed: Self.viewImports.union(["UICommon", "RegzaPresentation"]).union(Self.features))
    }

    /// Sources/UI の機能のフォルダと、Package.swift の機能の一覧 (features) が同じこと (フォルダだけ足しても、モジュールにならない)
    @Test func featureFoldersMatchPackage() throws {
        let manifest = try String(contentsOf: Self.package.appendingPathComponent("Package.swift"), encoding: .utf8)
        let list = try #require(manifest.range(of: #"let features = \[[^\]]*\]"#, options: .regularExpression))
        let declared = manifest[list].split(separator: "\"").enumerated().filter { $0.offset % 2 == 1 }.map { String($0.element) }
        #expect(!Self.features.isEmpty)
        #expect(declared.sorted() == Self.features)
    }

    @Test func liveActivityImportsOnlyPresentation() throws {
        try Self.check("Platform/LiveActivity", allowed: Self.liveActivityImports)
    }

    @Test func systemActionsImportOnlyPresentation() throws {
        try Self.check("Platform/SystemActions", allowed: Self.systemActionsImports)
    }

    @Test func shortcutsImportOnlyPresentation() throws {
        try Self.check("Platform/Shortcuts", allowed: Self.shortcutsImports)
    }

    @Test func widgetsImportOnlyPresentationAndSystemActions() throws {
        try Self.check("Platform/Widgets", allowed: Self.widgetsImports)
    }

    @Test func appServicesDoNotImportScreensOrEntryPoints() throws {
        try Self.check("Platform/AppServices", allowed: Self.appServicesImports)
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
