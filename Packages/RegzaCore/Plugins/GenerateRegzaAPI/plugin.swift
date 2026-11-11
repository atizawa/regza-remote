import Foundation
import PackagePlugin

@main
struct GenerateRegzaAPI: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let specification = context.package.directoryURL.appending(path: "../../OpenAPI/regza-tv.yaml").standardized
        let configuration = context.package.directoryURL.appending(path: "Sources/\(target.name)/openapi-generator-config.yaml")
        let output = context.pluginWorkDirectoryURL
        return [
            .buildCommand(
                displayName: "Generate REGZA OpenAPI client",
                executable: try context.tool(named: "swift-openapi-generator").url,
                arguments: ["generate", specification.path, "--config", configuration.path, "--output-directory", output.path],
                inputFiles: [specification, configuration],
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
