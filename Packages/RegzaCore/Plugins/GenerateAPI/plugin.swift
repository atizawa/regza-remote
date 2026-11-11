import Foundation
import PackagePlugin

@main
struct GenerateAPI: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let filename: String
        switch target.name {
        case "RegzaTVAPI": filename = "regza-tv.yaml"
        case "MirakurunAPI": filename = "mirakurun.json"
        case "EPGStationAPI": filename = "epgstation.json"
        default: return []
        }
        let source = context.package.directoryURL.appending(path: "../../OpenAPI/\(filename)").standardized
        let configuration = context.package.directoryURL.appending(path: "Sources/\(target.name)/openapi-generator-config.yaml")
        let output = context.pluginWorkDirectoryURL
        let generator = try context.tool(named: "swift-openapi-generator").url
        let executable: URL
        let arguments: [String]
        if target.name == "RegzaTVAPI" {
            executable = generator
            arguments = ["generate", source.path, "--config", configuration.path, "--output-directory", output.path]
        } else {
            executable = try context.tool(named: "PrepareOpenAPI").url
            // 中間仕様はアプリの resource として同梱しない。宣言する成果物は Swift のみ。
            arguments = [
                target.name, source.path, output.appending(path: "openapi.json").path,
                generator.path, configuration.path, output.path,
            ]
        }
        return [
            .buildCommand(
                displayName: "Generate \(target.name) OpenAPI client",
                executable: executable,
                arguments: arguments,
                inputFiles: [source, configuration, generator],
                outputFiles: [
                    "Types.swift", "Types+Components.swift", "Types+Operations.swift",
                    "Types+Components+Schemas.swift", "Types+Components+Parameters.swift",
                    "Types+Components+RequestBodies.swift", "Types+Components+Responses.swift",
                    "Types+Components+Headers.swift", "Client.swift",
                ].map { output.appending(path: $0) }
            )
        ]
    }
}
