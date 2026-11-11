import Foundation

/// サーバーから取得した仕様の原本を保ち、アプリ用の入力をビルドディレクトリに作る。
/// 汎用 Swagger 変換器ではなく、利用する GET 操作の parameter/response だけを OpenAPI 3 に変換する。
@main
struct PrepareOpenAPI {
    struct InvalidSpecification: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }

    static func main() throws {
        guard [4, 7].contains(CommandLine.arguments.count) else {
            throw InvalidSpecification("Usage: PrepareOpenAPI <API> <source> <output> [<generator> <config> <directory>]")
        }
        let arguments = CommandLine.arguments
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        guard var document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InvalidSpecification("OpenAPI specification must be an object")
        }
        switch arguments[1] {
        case "MirakurunAPI": document = try mirakurun(document)
        case "EPGStationAPI": document = try epgStation(document)
        default: throw InvalidSpecification("Unknown API: \(arguments[1])")
        }
        let output = URL(fileURLWithPath: arguments[3])
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
        if arguments.count == 7 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: arguments[4])
            process.arguments = ["generate", output.path, "--config", arguments[5], "--output-directory", arguments[6]]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw InvalidSpecification("OpenAPI generation failed") }
        }
    }

    static func mirakurun(_ source: [String: Any]) throws -> [String: Any] {
        guard source["swagger"] as? String == "2.0",
            let paths = source["paths"] as? [String: [String: Any]],
            var schemas = source["definitions"] as? [String: [String: Any]],
            let info = source["info"] as? [String: Any],
            let basePath = source["basePath"] as? String
        else { throw InvalidSpecification("Expected Mirakurun Swagger 2.0 paths, definitions, info and basePath") }
        var convertedPaths: [String: Any] = [:]
        for path in ["/version", "/programs", "/programs/{id}"] {
            guard let item = paths[path], var operation = item["get"] as? [String: Any],
                let responses = operation["responses"] as? [String: [String: Any]]
            else { throw InvalidSpecification("Missing Mirakurun GET \(path)") }
            let sharedParameters = try parameters(item["parameters"])
            operation["parameters"] = try parameters(operation["parameters"])
            operation["responses"] = try responses.mapValues { response in
                guard let schema = response["schema"] else {
                    throw InvalidSpecification("Expected JSON response schema for GET \(path)")
                }
                var response = response
                response.removeValue(forKey: "schema")
                response["content"] = ["application/json": ["schema": schema]]
                return response
            }
            convertedPaths[path] = ["parameters": sharedParameters, "get": operation]
        }
        // 従来の読取りと同じ項目だけをモデル化する。未使用の映像・音声等の enum に読取りを左右されない。
        try projectSchema(
            "Program", in: &schemas,
            fields: ["id", "eventId", "serviceId", "networkId", "startAt", "duration", "name", "description", "extended", "genres"],
            optional: ["eventId", "duration"])
        let document: [String: Any] = [
            "openapi": "3.0.3", "info": info,
            "servers": [["url": "http://localhost" + basePath]],
            "paths": convertedPaths, "components": ["schemas": schemas],
        ]
        guard let converted = replaceDefinitionReferences(document) as? [String: Any] else {
            throw InvalidSpecification("Failed to convert Mirakurun references")
        }
        return converted
    }

    static func parameters(_ value: Any?) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let parameters = value as? [[String: Any]] else { throw InvalidSpecification("Expected Swagger parameter array") }
        return try parameters.map { parameter in
            guard let location = parameter["in"] as? String, ["path", "query", "header"].contains(location),
                parameter["name"] is String, parameter["type"] is String
            else { throw InvalidSpecification("Only inline Swagger path/query/header parameters are supported") }
            var result: [String: Any] = [:]
            var schema = parameter
            for key in ["in", "name", "description", "required"] {
                result[key] = schema.removeValue(forKey: key)
            }
            guard schema["collectionFormat"] == nil else { throw InvalidSpecification("Swagger collectionFormat is not supported") }
            result["schema"] = schema
            return result
        }
    }

    static func epgStation(_ source: [String: Any]) throws -> [String: Any] {
        guard (source["openapi"] as? String)?.hasPrefix("3.") == true,
            let paths = source["paths"] as? [String: [String: Any]],
            var components = source["components"] as? [String: Any],
            var schemas = components["schemas"] as? [String: [String: Any]]
        else { throw InvalidSpecification("Expected EPGStation OpenAPI 3 paths and schemas") }
        let operations = [
            ("/version", "get", "getVersion"),
            ("/streams/live/{channelId}/hls", "get", "startLiveStream"),
            ("/streams", "get", "getStreams"),
            ("/streams/{streamId}/keep", "put", "keepStream"),
            ("/streams/{streamId}", "delete", "stopStream"),
        ]
        var selected: [String: Any] = [:]
        for (path, method, identifier) in operations {
            guard let item = paths[path], var operation = item[method] as? [String: Any] else {
                throw InvalidSpecification("Missing EPGStation \(method) \(path)")
            }
            operation["operationId"] = identifier
            var result = [method: operation] as [String: Any]
            result["parameters"] = item["parameters"]
            selected[path] = result
        }
        // 従来どおり streamId のない項目は無視し、isEnable がないときは false にする。
        try projectSchema("StreamInfoItem", in: &schemas, fields: ["streamId", "isEnable"], optional: ["streamId", "isEnable"])
        components["schemas"] = schemas
        var document = source
        document["paths"] = selected
        document["components"] = components
        return document
    }

    static func projectSchema(_ name: String, in schemas: inout [String: [String: Any]], fields: [String], optional: Set<String>) throws {
        guard var schema = schemas[name], let properties = schema["properties"] as? [String: Any],
            fields.allSatisfy({ properties[$0] != nil })
        else { throw InvalidSpecification("Missing properties in schema \(name)") }
        schema["properties"] = properties.filter { fields.contains($0.key) }
        if let required = schema["required"] as? [String] {
            schema["required"] = required.filter { fields.contains($0) && !optional.contains($0) }
            if (schema["required"] as? [String])?.isEmpty == true { schema.removeValue(forKey: "required") }
        }
        schemas[name] = schema
    }

    static func replaceDefinitionReferences(_ value: Any) -> Any {
        if let array = value as? [Any] { return array.map(replaceDefinitionReferences) }
        guard let object = value as? [String: Any] else { return value }
        var result: [String: Any] = [:]
        for (key, value) in object {
            if key == "$ref", let reference = value as? String, reference.hasPrefix("#/definitions/") {
                result[key] = reference.replacingOccurrences(of: "#/definitions/", with: "#/components/schemas/")
            } else {
                result[key] = replaceDefinitionReferences(value)
            }
        }
        return result
    }
}
