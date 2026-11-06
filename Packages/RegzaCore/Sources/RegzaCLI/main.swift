import Foundation
import RegzaCore

// regza: Mac で ViewModel を動かし、画面を通さずに状態を読んで操作する CLI (Shopify の Reflex の CLI と同じ考え方)。
//
//   swift run regza --sample                                   見本の通信で動かす (テレビにつながない)
//   swift run regza --host 192.0.2.10 --user U --password P    テレビにつなぐ (REGZA_HOST などの環境変数でもよい)
//
// 標準入力から 1 行ずつ命令を受け取り、結果を JSON で標準出力に書く:
//   tree                         ViewModel の道の一覧
//   ls [道]                      状態と操作の一覧 (道を省くと app)
//   do 道 操作 [JSON の引数]     操作して、通信などが終わるのを待ってから状態を返す
//   wait 秒                      待つ (定期の取得などを進める)
//   quit

@MainActor
func main() async {
    let options = Options(CommandLine.arguments.dropFirst(), environment: ProcessInfo.processInfo.environment)
    let store = MemoryConnectionStore(connection: RegzaConnection(host: options.host, user: options.user, password: options.password))
    let transport: any HTTPTransport = options.sample ? SampleTransport() : SocketTransport()
    let app = AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport))
    let introspector = Introspector(root: app)
    if !options.host.isEmpty {
        // チャンネル一覧などを使う操作のため、先に読んでおく
        try? await app.remote.loadChannels()
    }

    print(#"{"ready":true}"#)
    do {
        for try await line in FileHandle.standardInput.bytes.lines {
            let words = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true).map(String.init)
            guard let command = words.first else { continue }
            if command == "quit" { break }
            print(await run(command, Array(words.dropFirst()), introspector))
            fflush(stdout)
        }
    } catch {
        print(JSONValue.object(["error": .string("\(error)")]).json)
    }
}

@MainActor
func run(_ command: String, _ arguments: [String], _ introspector: Introspector) async -> String {
    do {
        switch command {
        case "tree":
            return JSONValue.array(introspector.paths().map(JSONValue.string)).json
        case "ls":
            return try encode(introspector.node(arguments.first ?? "app"))
        case "do":
            guard arguments.count >= 2 else { return failure("do 道 操作 [JSON の引数]") }
            let parameters: [String: JSONValue]
            if arguments.count > 2 {
                guard case .object(let object) = try JSONDecoder().decode(JSONValue.self, from: Data(arguments[2].utf8)) else {
                    return failure("引数は JSON のオブジェクトで渡す")
                }
                parameters = object
            } else {
                parameters = [:]
            }
            try introspector.perform(arguments[0], arguments[1], parameters)
            let idle = await introspector.waitUntilIdle()
            var node = try introspector.node(arguments[0])
            if !idle { node.isBusy = true }
            return try encode(node)
        case "wait":
            let seconds = arguments.first.flatMap(Double.init) ?? 1
            try await Task.sleep(for: .seconds(seconds))
            return #"{"waited":\#(seconds)}"#
        default:
            return failure("命令は tree・ls・do・wait・quit")
        }
    } catch {
        return failure("\(error)")
    }
}

func encode(_ node: IntrospectionNode) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(node), as: UTF8.self)
}

func failure(_ message: String) -> String {
    JSONValue.object(["error": .string(message)]).json
}

struct Options {
    var sample = false
    var host = ""
    var user = ""
    var password = ""

    init(_ arguments: ArraySlice<String>, environment: [String: String]) {
        host = environment["REGZA_HOST"] ?? ""
        user = environment["REGZA_USER"] ?? ""
        password = environment["REGZA_PASSWORD"] ?? ""
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--sample": sample = true
            case "--host": host = iterator.next() ?? host
            case "--user": user = iterator.next() ?? user
            case "--password": password = iterator.next() ?? password
            default: break
            }
        }
        if sample, host.isEmpty { host = "192.0.2.10" }
    }
}

await main()
