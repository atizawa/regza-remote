import Foundation
import Testing

/// 画面の名前が、iOS・Android・共有の ViewModel でそろっていることを確かめる。
/// 共有の ViewModel のフォルダ (RegzaPresentation/ViewModels/<名前>/) ごとに、iOS は `<名前>Screen.swift` に `struct <名前>Screen`、
/// Android は `<名前>Screen.kt` に `fun <名前>Screen(` を置く (1 画面 1 ファイル。iOS は画面のモジュール (Sources/UI の下)、
/// Android は画面のモジュール (ui/<機能>) か組み立て (app) の ui/ の下)。画面でないものには Screen を付けない
@Suite struct ScreenNamingTests {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("../../../..").standardized
    static let viewModels = repository.appendingPathComponent("Packages/RegzaCore/Sources/RegzaPresentation/ViewModels")
    /// iOS の画面を置くモジュール (機能のモジュールと組み立て)
    static let iOSSources = repository.appendingPathComponent("iOS/RegzaKit/Sources")
    /// Android の画面を置くモジュール (画面のモジュール ui/<機能> と、組み立ての app)
    static let android = repository.appendingPathComponent("Android")

    /// 名前が Screen で終わるファイル (拡張子なし) と、その場所 (同じ名前が 2 つあれば、どちらも返す)
    static func screenFiles(under directory: URL, extension: String, in modules: (String) -> Bool = { _ in true }) throws
        -> [String: [URL]]
    {
        let paths = try FileManager.default.subpathsOfDirectory(atPath: directory.path)
        var files: [String: [URL]] = [:]
        for path in paths where modules(String(path.split(separator: "/").first ?? "")) {
            let url = directory.appendingPathComponent(path)
            let name = url.deletingPathExtension().lastPathComponent
            if url.pathExtension == `extension`, name.hasSuffix("Screen") { files[name, default: []].append(url) }
        }
        return files
    }

    static func iOSScreenFiles() throws -> [String: [URL]] {
        try screenFiles(under: iOSSources, extension: "swift") { $0 == "UI" }
    }

    static func androidScreenFiles() throws -> [String: [URL]] {
        let modules =
            ["app"]
            + (try FileManager.default.contentsOfDirectory(atPath: android.appendingPathComponent("ui").path)).map { "ui/\($0)" }
        var files: [String: [URL]] = [:]
        for module in modules {
            let ui = android.appendingPathComponent("\(module)/src/main/java/com/example/regzaremote/ui")
            guard FileManager.default.fileExists(atPath: ui.path) else { continue }
            files.merge(try screenFiles(under: ui, extension: "kt")) { $0 + $1 }
        }
        return files
    }

    /// 共有の ViewModel の名前 (ViewModels/ の下のフォルダ)
    static func screenNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: viewModels, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
    }

    @Test func everyViewModelHasScreenWithSameNameOnBothPlatforms() throws {
        let names = try Self.screenNames()
        #expect(names.count > 10, "共有の ViewModel のフォルダが見つかりません: \(Self.viewModels.path)")
        let iOSFiles = try Self.iOSScreenFiles()
        let androidFiles = try Self.androidScreenFiles()
        for name in names {
            let iOSSource = iOSFiles["\(name)Screen"]?.first.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            #expect(iOSSource?.contains("struct \(name)Screen") == true, "iOS に \(name)Screen.swift と struct \(name)Screen を置いてください")

            let androidSource = androidFiles["\(name)Screen"]?.first.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            #expect(androidSource?.contains("fun \(name)Screen(") == true, "Android に \(name)Screen.kt と fun \(name)Screen( を置いてください")
        }
    }

    @Test func screenSuffixIsOnlyForViewModelScreens() throws {
        let expected = Set(try Self.screenNames().map { "\($0)Screen" })
        let iOS = Set(try Self.iOSScreenFiles().keys)
        let android = Set(try Self.androidScreenFiles().keys)
        #expect(iOS.subtracting(expected).isEmpty, "共有の ViewModel のない iOS の画面: \(iOS.subtracting(expected).sorted())")
        #expect(android.subtracting(expected).isEmpty, "共有の ViewModel のない Android の画面: \(android.subtracting(expected).sorted())")
    }

    /// 1 画面 1 ファイル (機能のフォルダが分かれていても、同じ名前の画面のファイルは 1 つだけ)
    @Test func eachScreenHasOneFile() throws {
        for (platform, files) in [("iOS", try Self.iOSScreenFiles()), ("Android", try Self.androidScreenFiles())] {
            let duplicated = files.filter { $0.value.count > 1 }
            #expect(duplicated.isEmpty, "\(platform) に同じ名前の画面のファイルが複数あります: \(duplicated.mapValues { $0.map(\.path) })")
        }
    }
}
