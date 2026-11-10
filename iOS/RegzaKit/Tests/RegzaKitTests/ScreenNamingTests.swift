import Foundation
import Testing

/// 画面の名前が、iOS・Android・共有の ViewModel でそろっていることを確かめる。
/// 共有の ViewModel のフォルダ (RegzaPresentation/ViewModels/<名前>/) ごとに、iOS は `<名前>Screen.swift` に `struct <名前>Screen`、
/// Android は `<名前>Screen.kt` に `fun <名前>Screen(` を置く (1 画面 1 ファイル)。画面でないものには Screen を付けない
@Suite struct ScreenNamingTests {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("../../../..").standardized
    static let viewModels = repository.appendingPathComponent("Packages/RegzaCore/Sources/RegzaPresentation/ViewModels")
    static let iOSScreens = repository.appendingPathComponent("iOS/RegzaKit/Sources/RegzaRemoteViews")
    static let androidScreens = repository.appendingPathComponent("Android/app/src/main/java/com/example/regzaremote")

    /// 共有の ViewModel の名前 (ViewModels/ の下のフォルダ)
    static func screenNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: viewModels, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
    }

    /// フォルダの中で、名前が Screen で終わるファイルの名前 (拡張子なし)
    static func screenFiles(in directory: URL, extension: String) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == `extension` }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasSuffix("Screen") })
    }

    @Test func everyViewModelHasScreenWithSameNameOnBothPlatforms() throws {
        let names = try Self.screenNames()
        #expect(names.count > 10, "共有の ViewModel のフォルダが見つかりません: \(Self.viewModels.path)")
        for name in names {
            let iOS = Self.iOSScreens.appendingPathComponent("\(name)Screen.swift")
            let iOSSource = try? String(contentsOf: iOS, encoding: .utf8)
            #expect(iOSSource?.contains("struct \(name)Screen") == true, "iOS に \(name)Screen.swift と struct \(name)Screen を置いてください")

            let android = Self.androidScreens.appendingPathComponent("\(name)Screen.kt")
            let androidSource = try? String(contentsOf: android, encoding: .utf8)
            #expect(androidSource?.contains("fun \(name)Screen(") == true, "Android に \(name)Screen.kt と fun \(name)Screen( を置いてください")
        }
    }

    @Test func screenSuffixIsOnlyForViewModelScreens() throws {
        let expected = Set(try Self.screenNames().map { "\($0)Screen" })
        let iOS = try Self.screenFiles(in: Self.iOSScreens, extension: "swift")
        let android = try Self.screenFiles(in: Self.androidScreens, extension: "kt")
        #expect(iOS.subtracting(expected).isEmpty, "共有の ViewModel のない iOS の画面: \(iOS.subtracting(expected).sorted())")
        #expect(android.subtracting(expected).isEmpty, "共有の ViewModel のない Android の画面: \(android.subtracting(expected).sorted())")
    }
}
