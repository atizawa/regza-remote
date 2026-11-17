import Foundation

/// 画面ごとのフォルダの State/ と Action/ に置いた型から、窓口のつなぎを作る (画面を足しても手で書かずに済むようにする)。
///
/// - RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift
///   画面の Action (ViewModel のファイルに「typealias Action = 型」と書いた型) ごとに、窓口 (RegzaAndroidApp) の送る関数を作る。
///   送り先は、その型を Action にしている ViewModel。swift-java は同じ名前の関数を並べられないので、
///   名前は型ごとに変える (send<Action の型>)。
///   ほかの Action の case の値に使う部品の操作は Java のクラスにするだけで、送る関数は作らない
///   (1 つの画面には 1 つの Action で送る)。どちらでもない型が Action/ にあれば止める。
///   あわせて画面の ViewModel (「typealias State = 型」) ごとに、state を返す関数 (<State の型 (先頭は小文字)>(route:)) と、
///   変わるまで待って返す関数 (next<State の型>(route:after:waitID:)) を作る。
///   Kotlin の Flow が終わったら waitID を endStateWait に渡し、待っている Swift の Task も終わらせる
/// - .build/swift/screen-glue-kotlin/<モジュール>/<接頭辞>Screens.kt (Gradle の :presentation:<モジュール> に入る)
///   プレゼンテーションのモジュールごとの、画面が受け取る送り先 (<接頭辞>Send。その機能の操作を型ごとの invoke で送る。
///   共通の CoreSend を受け継ぎ、リモコンの操作と画面の移り変わり (AppNavigator) も送れる) と、
///   プレビューが受け取るアプリ (<接頭辞>App。送り先と、その機能の画面の state の購読)。
///   機能の画面は自分の機能のものだけを使うので、ほかの機能の型は見えない
/// - .build/swift/screen-glue-kotlin/bridge/ScreenGlue.kt (Gradle の :core:bridge に入る)
///   すべての送り先をまとめた Send と、Swift の窓口に送る SwiftSend、プレビューに渡す SwiftApp。
///   state は型ごとに Flow にする (<State の型 (先頭は小文字)>s(route))。ビルドのたびに作るので保存しない
/// - .build/swift/presentation-types.txt
///   State/ と Action/ の型ごとの Gradle のモジュール (「型 モジュール」の行)。build-swift が、型の Java のクラスをモジュールに分ける
/// - swift-java の設定の、ほかのモジュールの型の一覧 (importedModuleStubs の行)
///   RegzaPresentation.swift-java.config と RegzaAndroidBridge.swift-java.config の "RegzaSharedModels" の行に
///   RegzaSharedModels の型を、RegzaAndroidBridge.swift-java.config の "RegzaPresentation" の行に State/ と Action/ の型を書く
///   (書いていない型を使うところは、swift-java が黙って飛ばす)
public struct ScreenGlue {
    /// 作るファイルの、Android/ からの場所と中身
    public let files: [(path: String, contents: String)]
    /// --check で確かめるファイル (Git に入れるもの。Kotlin はビルドのたびに作るので確かめない)
    public let checkedPaths: Set<String>

    static let actionsPath = "RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift"
    static let presentationConfigPath = "RegzaAndroid/RegzaPresentation.swift-java.config"
    static let bridgeConfigPath = "RegzaAndroid/RegzaAndroidBridge.swift-java.config"
    static let kotlinDirectory = ".build/swift/screen-glue-kotlin"
    static let kotlinPath = "\(kotlinDirectory)/bridge/ScreenGlue.kt"
    static let typesPath = ".build/swift/presentation-types.txt"
    static let header = "// ScreenGlue (Android/ScreenGlue の screen-glue) が作る (手で直さない)"

    /// - Parameter android: Android/ のフォルダ
    public init(android: URL) throws {
        let core = android.appending(path: "../Packages/RegzaCore/Sources")
        let sources = try Sources(
            viewModels: core.appending(path: "Presentation"),
            sharedModels: core.appending(path: "RegzaSharedModels")
        )
        let presentationConfig = try String(contentsOf: android.appending(path: Self.presentationConfigPath), encoding: .utf8)
        let bridgeConfig = try String(contentsOf: android.appending(path: Self.bridgeConfigPath), encoding: .utf8)
        let shared = sources.sharedStubs.map(\.text)
        files =
            [
                (Self.actionsPath, Self.swiftActions(sources.screens)),
                (
                    Self.presentationConfigPath,
                    try Self.replacingStubs(
                        in: presentationConfig, module: "RegzaSharedModels", with: shared, path: Self.presentationConfigPath)
                ),
                (
                    Self.bridgeConfigPath,
                    try Self.replacingStubs(
                        in: try Self.replacingStubs(
                            in: bridgeConfig, module: "RegzaSharedModels", with: shared, path: Self.bridgeConfigPath),
                        module: "RegzaPresentation", with: sources.presentationStubs.map(\.text), path: Self.bridgeConfigPath
                    )
                ),
                (Self.kotlinPath, Self.kotlin(sources.screens)),
                (Self.typesPath, sources.typeModules.map { "\($0.type) \($0.module)\n" }.joined()),
            ]
            + Self.modules(of: sources.screens).map { module in
                ("\(Self.kotlinDirectory)/\(module)/\(Self.prefix(module))Screens.kt", Self.moduleKotlin(module, sources.screens))
            }
        checkedPaths = [Self.actionsPath, Self.presentationConfigPath, Self.bridgeConfigPath]
    }

    /// 作ったものを書く
    public func write(android: URL) throws {
        for (path, contents) in files {
            let url = android.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Git に入れるものが、作り直したものと同じか確かめる。古いファイルの Android/ からの場所を返す (古くなければ空)
    public func outdatedPaths(android: URL) -> [String] {
        files.filter { checkedPaths.contains($0.path) }.compactMap { path, contents in
            let current = try? String(contentsOf: android.appending(path: path), encoding: .utf8)
            return current == contents ? nil : path
        }
    }

    // MARK: - 窓口 (Swift)

    static func swiftActions(_ screens: [Screen]) -> String {
        let actions = screens.map { screen in
            """

                /// \(screen.viewModel) に送る
                public func send\(screen.action)(_ action: \(screen.action)) {
                    Task { @MainActor in self.perform(action) }
                }

                /// \(screen.viewModel) に送る (テストからは、送った順を待たずに直接呼ぶ)
                @MainActor func perform(_ action: \(screen.action)) {
                    route { ($0 as? \(screen.viewModel))?.send(action) != nil }
                }

            """
        }
        let states = screens.map { screen in
            let state = screen.state
            return """

                    /// \(screen.viewModel) の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
                    public func \(stateFunction(state))(route: AppRoute?) async -> \(state)? {
                        await MainActor.run { self.state(route: route) { ($0 as? \(screen.viewModel))?.state } }
                    }

                    /// \(screen.viewModel) の state が after から変わるまで待って返す
                    public func next\(state)(route: AppRoute?, after: \(state)?, waitID: Int64) async -> \(state)? {
                        await nextState(route: route, after: after, waitID: waitID) { @MainActor in ($0 as? \(screen.viewModel))?.state }
                    }

                """
        }
        // 振る舞いのテストの Android 側の相手の口 (約束事の操作を Action にできる ViewModel だけ。IntrospectableActions)
        let contracts = screens.filter(\.isIntrospectable).map { screen in
            """

                /// 振る舞いのテストの Android 側の相手: 約束事の操作を \(screen.action) にする (アプリと同じ道で送るため)。できなければ nil
                public func contract\(screen.action)(path: String, action: String, arguments: String) async -> \(screen.action)? {
                    await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? \(screen.action) }
                }

                /// 振る舞いのテストの Android 側の相手: \(screen.state) を regza と同じ JSON にする (\(screen.viewModel) の見せ方を使う)
                public func contract\(screen.state)JSON(_ state: \(screen.state)?) -> String {
                    state.map { \(screen.viewModel).introspectionJSON(of: $0) }?.json ?? "null"
                }

            """
        }
        return """
            \(header)
            import RegzaApp

            // MARK: - 操作

            extension RegzaAndroidApp {\(actions.joined())}

            // MARK: - state

            extension RegzaAndroidApp {\(states.joined())}

            // MARK: - 振る舞いのテストの Android 側の相手

            extension RegzaAndroidApp {\(contracts.joined())}

            """
    }

    /// state を返す関数の名前 (State の型の先頭を小文字にしたもの)
    static func stateFunction(_ state: String) -> String {
        state.prefix(1).lowercased() + state.dropFirst()
    }

    // MARK: - swift-java の設定

    /// 設定の "モジュール名": [...] の行を、型の一覧に置き換える (次の行が続くなら、置き換える前と同じく行の終わりに , を付ける)
    static func replacingStubs(in config: String, module: String, with stubs: [String], path: String) throws -> String {
        let prefix = "    \"\(module)\": "
        var lines = config.components(separatedBy: "\n")
        while lines.last == "" { lines.removeLast() }
        guard let index = lines.firstIndex(where: { $0.hasPrefix(prefix) }) else {
            throw ScreenGlueError("\(path) に \"\(module)\" の行がありません")
        }
        let list = stubs.map { "\"\($0)\"" }.joined(separator: ", ")
        lines[index] = prefix + "[\(list)]" + (lines[index].hasSuffix(",") ? "," : "")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Kotlin

    /// 画面のあるモジュール (共通の core が先、アプリ全体の app が後、ほかは名前の順)
    static func modules(of screens: [Screen]) -> [String] {
        let names = Set(screens.map(\.module))
        return names.sorted { a, b in
            let order = { (name: String) in name == "core" ? 0 : name == "app" ? 2 : 1 }
            return (order(a), a) < (order(b), b)
        }
    }

    /// モジュールの送り先などの名前の接頭辞 (core なら Core、guide なら Guide)
    static func prefix(_ module: String) -> String {
        module.prefix(1).uppercased() + module.dropFirst()
    }

    /// プレビューが受け取るアプリ (<接頭辞>App) を作るか (アプリ全体のモジュールは組み立てだけが使うので作らない)
    static func hasPreviewApp(_ module: String) -> Bool { module != "app" }

    /// プレゼンテーションのモジュールごとの、画面が受け取る送り先と、プレビューが受け取るアプリ
    static func moduleKotlin(_ module: String, _ allScreens: [Screen]) -> String {
        let screens = allScreens.filter { $0.module == module }
        let name = prefix(module)
        let isCore = module == "core"
        let previewApp = hasPreviewApp(module)
        var imports = screens.flatMap { ["com.example.regzaremote.core.\($0.action)", "com.example.regzaremote.core.\($0.state)"] }
        if previewApp { imports += ["com.example.regzaremote.core.AppRoute", "kotlinx.coroutines.flow.Flow"] }
        if !isCore {
            imports.append("com.example.regzaremote.presentation.core.CoreSend")
            if previewApp { imports.append("com.example.regzaremote.presentation.core.CoreApp") }
        }
        let invokes = screens.map { "\n    /** \($0.viewModel) に送る */\n    operator fun invoke(action: \($0.action))\n" }
        let flows = screens.map {
            "\n    /** \($0.viewModel) の state を、変わるたびに流す (route を渡せばその画面の ViewModel の。開いていなければ null) */"
                + "\n    fun \(stateFunction($0.state))s(route: AppRoute? = null): Flow<\($0.state)?>\n"
        }
        let send = """
            /**
             * \(isCore ? "共通の送り先。リモコンの操作と、画面の移り変わり (AppNavigator) を送る" : "\(name) の画面から送る先。この機能の画面の操作を送る。共通の送り先 (CoreSend) を受け継ぎ、リモコンの操作と画面の移り変わりも送れる")
             */
            interface \(name)Send : \(isCore ? "AppNavigator" : "CoreSend") {\(invokes.joined())}

            """
        let app =
            !previewApp
            ? ""
            : """

            /** \(isCore ? "画面のプレビューが受け取るアプリの共通の部分。送り先と、共通" : "\(name) の画面のプレビューが受け取るアプリ。送り先と、この機能")の画面の state の購読 */
            interface \(name)App : \(name)Send\(isCore ? "" : ", CoreApp") {\(flows.joined())}

            """
        return """
            \(header)
            package com.example.regzaremote.presentation.\(module)

            \(imports.sorted().map { "import \($0)\n" }.joined())
            \(send)\(app)
            """
    }

    /// :core:bridge に入れるもの: すべての送り先をまとめた Send、Swift の窓口に送る SwiftSend、state の Flow、プレビューに渡す SwiftApp
    static func kotlin(_ screens: [Screen]) -> String {
        let modules = modules(of: screens)
        let imports = screens.map { "import com.example.regzaremote.core.\($0.action)\nimport com.example.regzaremote.core.\($0.state)\n" }
        let moduleImports = modules.flatMap { module in
            ["import com.example.regzaremote.presentation.\(module).\(prefix(module))Send\n"]
                + (hasPreviewApp(module) ? ["import com.example.regzaremote.presentation.\(module).\(prefix(module))App\n"] : [])
        }
        let overrides = screens.map { "\n    override fun invoke(action: \($0.action)) = app.send\($0.action)(action)" }
        let appFlows = screens.filter { hasPreviewApp($0.module) }.map {
            "\n    override fun \(stateFunction($0.state))s(route: AppRoute?) = app.\(stateFunction($0.state))s(route)"
        }
        let sends = modules.map { "\(prefix($0))Send" }.joined(separator: ", ")
        let apps = modules.filter(hasPreviewApp).map { "\(prefix($0))App" }.joined(separator: ", ")
        let flows = screens.map { screen in
            let state = screen.state
            return """

                /** \(screen.viewModel) の state を、変わるたびに流す (route を渡せばその画面の ViewModel の。開いていなければ null) */
                fun RegzaAndroidApp.\(stateFunction(state))s(route: AppRoute? = null): Flow<\(state)?> = flow {
                    var state = \(stateFunction(state))(Optional.ofNullable(route)).await().orElse(null)
                    while (true) {
                        emit(state)
                        state = waitForNextState { waitID ->
                            next\(state)(Optional.ofNullable(route), Optional.ofNullable(state), waitID)
                        }
                    }
                }

                """
        }
        let introspectable = screens.filter(\.isIntrospectable)
        let contractSends = introspectable.map {
            "\n        \"\($0.viewModel)\" -> send(contract\($0.action)(path, action, arguments).await().orElse(null) ?: return false)"
        }
        let contractStates = introspectable.map {
            "\n    \"\($0.viewModel)\" -> contract\($0.state)JSON(\(stateFunction($0.state))(Optional.ofNullable(route)).await())"
        }
        return """
            \(header)
            package com.example.regzaremote.bridge

            \(imports.joined())\(moduleImports.joined())import com.example.regzaremote.core.AppRoute
            import com.example.regzaremote.core.RegzaAndroidApp
            import java.util.Optional
            import java.util.concurrent.CompletableFuture
            import java.util.concurrent.atomic.AtomicLong
            import kotlinx.coroutines.NonCancellable
            import kotlinx.coroutines.flow.Flow
            import kotlinx.coroutines.flow.flow
            import kotlinx.coroutines.future.await
            import kotlinx.coroutines.withContext

            /**
             * swift-java の Future は、Kotlin から取り消しても元の Swift Task を取り消さない。
             * 1 回の待機に番号を付け、正常に受け取ったときも Flow が終わったときも Swift 側へ終了を知らせる。
             */
            private val stateWaitIDs = AtomicLong()

            private suspend fun <State> RegzaAndroidApp.waitForNextState(
                next: (Long) -> CompletableFuture<Optional<State>>,
            ): State? {
                val waitID = stateWaitIDs.incrementAndGet()
                return try {
                    next(waitID).await().orElse(null)
                } finally {
                    // 取り消されたコルーチンの finally でも、Swift の continuation を起こし終わるまで待つ
                    withContext(NonCancellable) { endStateWait(waitID).await() }
                }
            }

            /**
             * 画面から操作を送る先。すべての画面の操作を send(...) で送る (アプリの組み立てが使う)。
             * 機能の画面は、それぞれの機能の送り先 (<機能>Send) として受け取る
             */
            interface Send : \(sends)

            /** Swift の窓口 (RegzaAndroidApp) に送る。画面の移り変わりは、アプリ全体の操作にして送る (AppActionNavigator) */
            class SwiftSend(private val app: RegzaAndroidApp) : Send, AppActionNavigator {\(overrides.joined())
            }
            \(flows.joined())
            /** 偽物で組み立てたアプリを、画面のプレビューに渡す (どの機能のプレビューが受け取るアプリ (<機能>App) としても使える) */
            class SwiftApp(val app: RegzaAndroidApp) : Send by SwiftSend(app), \(apps) {\(appFlows.joined())
            }

            /** 振る舞いのテストの Android 側の相手: 道の ViewModel の型ごとに、約束事の操作をアプリと同じ道 (send) で送る。送れなければ false */
            suspend fun RegzaAndroidApp.contractSend(type: String, path: String, action: String, arguments: String): Boolean {
                val send = SwiftSend(this)
                when (type) {\(contractSends.joined())
                    else -> return false
                }
                return true
            }

            /** 振る舞いのテストの Android 側の相手: 道の ViewModel の型ごとに、アプリと同じ道 (xxxState) で state を受け取り、regza と同じ JSON にする */
            suspend fun RegzaAndroidApp.contractStateJSON(type: String, route: AppRoute?): String? = when (type) {\(contractStates.joined())
                else -> null
            }

            """
    }
}
