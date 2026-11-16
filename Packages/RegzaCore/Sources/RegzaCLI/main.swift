import Foundation
import RegzaApp
import RegzaFakeServers

// regza: Mac で ViewModel を動かし、画面を通さずに状態を読んで操作する CLI (Shopify の Reflex の CLI と同じ考え方)。
//
//   swift run regza --fake                                     偽物のテレビ・録画サーバーにつなぐ (本物にはつながない)
//   swift run regza --fake --scenario <JSON のファイル>        偽物の場面を選ぶ (FakeScenario。振る舞いのテストで使う)
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
    let appViewModel: AppViewModel
    if options.fake {
        do {
            let scenario = try options.scenario.map { try FakeScenario(json: String(contentsOfFile: $0, encoding: .utf8)) } ?? .standard
            appViewModel = FakeApp.makeAppViewModel(scenario: scenario)
        } catch {
            output(IntrospectionSession.failure("場面を読めません: \(error)"))
            return
        }
    } else {
        let secureStorageManager = SecureStorageManager(
            storage: MemorySecureStorage(values: [.password: options.password, .pairingUserID: FakeScenario.pairingUserID]))
        let preferencesManager = PreferencesManager(storage: MemoryPreferencesStorage(values: [.host: options.host, .user: options.user]))
        appViewModel = AppFactory.makeLiveAppViewModel(
            secureStorageManager: secureStorageManager, preferencesManager: preferencesManager, transport: URLSessionTransport())
    }
    let session = IntrospectionSession(root: appViewModel)
    if !options.host.isEmpty, !options.fake {
        // チャンネル一覧などを使う操作のため、先に読んでおく
        appViewModel.remoteViewModel.send(.loadChannels(force: false))
        _ = await session.introspector.waitUntilIdle()
    }

    output(#"{"ready":true}"#)
    for await line in inputLines() {
        guard let command = IntrospectionSession.parse(line) else { continue }
        if command == .quit { break }
        output(await session.run(command))
    }
}

/// 1 行書く。パイプにつないで動かす (振る舞いのテストなど) ときも、ためずにすぐ相手に届ける
func output(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

/// 標準入力の行。読むのは別のスレッドで待つので、待っている間も MainActor の処理 (定期の取得など) は進む
/// (Linux の Foundation には FileHandle.bytes がないので、readLine で読む)
func inputLines() -> AsyncStream<String> {
    AsyncStream { continuation in
        Thread.detachNewThread {
            while let line = readLine() {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}

struct Options {
    var fake = false
    var scenario: String?
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
            case "--fake": fake = true
            case "--scenario": scenario = iterator.next()
            case "--host": host = iterator.next() ?? host
            case "--user": user = iterator.next() ?? user
            case "--password": password = iterator.next() ?? password
            default: break
            }
        }
    }
}

await main()
