import Foundation
import MockoloFramework

let repositoryURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let coreURL = repositoryURL.appendingPathComponent("Packages/RegzaCore")
let outputURL = coreURL.appendingPathComponent("Tests/RegzaCoreTests/Generated/DomainMocks.swift")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let generatedSource = try generate(
    sourceDirs: [coreURL.appendingPathComponent("Sources/RegzaDomain").path],
    sourceFiles: [], exclusionSuffixes: [], mockFilePaths: nil,
    annotation: "@mockable", header: nil, macro: nil, declType: .protocolType,
    useTemplateFunc: false, allowSetCallCount: false, enableFuncArgsHistory: true,
    disableCombineDefaultValues: false, mockFinal: true, testableImports: [],
    customImports: ["RegzaDomain", "RegzaSharedModels"], excludeImports: [],
    to: outputURL.path, loggingLevel: 2, concurrencyLimit: nil)

let normalizedSource =
    generatedSource
    .replacingOccurrences(of: "(?m)[\t ]+$", with: "", options: .regularExpression)
    .trimmingCharacters(in: .newlines) + "\n"
try normalizedSource.write(to: outputURL, atomically: true, encoding: .utf8)
