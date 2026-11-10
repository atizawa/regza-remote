import Foundation
import RegzaApp
import RegzaSample

// regza: Mac で ViewModel を動かし、画面を通さずに状態を読んで操作する CLI (Shopify の Reflex の CLI と同じ考え方)。
//
//   swift run regza --sample                                   見本の通信で動かす (テレビにつながない)
//   swift run regza --sample --fixture <JSON のファイル>       見本の返事を差し替える (SampleFixture。振る舞いのテストで使う)
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
    // 見本では、テレビと番組表 (Mirakurun)・録画サーバー (EPGStation) も見本の返事を使う (Android の見本と同じ登録)
    let store = MemoryConnectionStore(
        connection: options.sample && options.host.isEmpty
            ? SampleTransport.connection : RegzaConnection(host: options.host, user: options.user, password: options.password)
    )
    if options.sample {
        store.guideHost = SampleTransport.guideHost
        store.streamHost = SampleTransport.streamHost
    }
    let transport: any HTTPTransport
    if options.sample {
        do {
            let fixture =
                try options.fixture.map { try SampleFixture(json: String(contentsOfFile: $0, encoding: .utf8)) } ?? SampleFixture()
            transport = SampleTransport(fixture: fixture)
        } catch {
            print(IntrospectionSession.failure("fixture を読めません: \(error)"))
            return
        }
    } else {
        transport = SocketTransport()
    }
    // 番組表 (Mirakurun) や録画サーバーへの通信も同じ方法で送る
    RegzaHTTP.transport = transport
    let app = AppViewModel(store: store, remote: RegzaRemote(connection: store.load(), transport: transport))
    let session = IntrospectionSession(root: app)
    if !options.host.isEmpty, !options.sample {
        // チャンネル一覧などを使う操作のため、先に読んでおく
        app.remote.send(.loadChannels(force: false))
        _ = await session.introspector.waitUntilIdle()
    }

    print(#"{"ready":true}"#)
    // パイプにつないで動かす (振る舞いのテストなど) ときも、すぐ相手に届くようにする
    fflush(stdout)
    do {
        for try await line in FileHandle.standardInput.bytes.lines {
            guard let command = IntrospectionSession.parse(line) else { continue }
            if command == .quit { break }
            print(await session.run(command))
            fflush(stdout)
        }
    } catch {
        print(IntrospectionSession.failure("\(error)"))
    }
}

struct Options {
    var sample = false
    var fixture: String?
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
            case "--fixture": fixture = iterator.next()
            case "--host": host = iterator.next() ?? host
            case "--user": user = iterator.next() ?? user
            case "--password": password = iterator.next() ?? password
            default: break
            }
        }
    }
}

await main()
