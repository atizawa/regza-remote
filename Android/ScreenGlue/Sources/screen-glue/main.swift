import Foundation
import ScreenGlueKit

// screen-glue: 窓口のつなぎを作る (ScreenGlueKit の ScreenGlue)。Android/ で動かす (mise run build-swift が毎回動かす)。
//
//   swift run --package-path ScreenGlue screen-glue           作り直す
//   swift run --package-path ScreenGlue screen-glue --check   作り直さずに、Git に入れたつなぎが古くないかだけを確かめる

let android = URL(filePath: FileManager.default.currentDirectoryPath)
do {
    let glue = try ScreenGlue(android: android)
    if CommandLine.arguments.contains("--check") {
        let outdated = glue.outdatedPaths(android: android)
        guard outdated.isEmpty else {
            FileHandle.standardError.write(
                Data("screen-glue: 窓口のつなぎが古くなっています (\(outdated.joined(separator: "、")))。Android で mise run build-swift を実行してください\n".utf8)
            )
            exit(1)
        }
    } else {
        try glue.write(android: android)
    }
} catch {
    FileHandle.standardError.write(Data("screen-glue: \(error)\n".utf8))
    exit(1)
}
