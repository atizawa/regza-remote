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
/// - .build/swift/screen-glue-kotlin/ScreenGlue.kt
///   画面が受け取る送り先 (Send)。どの操作も send(...) で送れるよう型ごとの invoke を並べ、Swift の窓口に送る AppSend も作る。
///   state は型ごとに Flow にする (<State の型 (先頭は小文字)>s(route))。ビルドのたびに作るので保存しない
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
    static let kotlinPath = ".build/swift/screen-glue-kotlin/ScreenGlue.kt"
    static let header = "// ScreenGlue (Android/ScreenGlue の screen-glue) が作る (手で直さない)"

    /// - Parameter android: Android/ のフォルダ
    public init(android: URL) throws {
        let core = android.appending(path: "../Packages/RegzaCore/Sources")
        let sources = try Sources(
            viewModels: core.appending(path: "RegzaPresentation/ViewModels"),
            sharedModels: core.appending(path: "RegzaSharedModels")
        )
        let presentationConfig = try String(contentsOf: android.appending(path: Self.presentationConfigPath), encoding: .utf8)
        let bridgeConfig = try String(contentsOf: android.appending(path: Self.bridgeConfigPath), encoding: .utf8)
        let shared = sources.sharedStubs.map(\.text)
        files = [
            (Self.actionsPath, Self.swiftActions(sources.screens)),
            (
                Self.presentationConfigPath,
                try Self.replacingStubs(
                    in: presentationConfig, module: "RegzaSharedModels", with: shared, path: Self.presentationConfigPath)
            ),
            (
                Self.bridgeConfigPath,
                try Self.replacingStubs(
                    in: try Self.replacingStubs(in: bridgeConfig, module: "RegzaSharedModels", with: shared, path: Self.bridgeConfigPath),
                    module: "RegzaPresentation", with: sources.presentationStubs.map(\.text), path: Self.bridgeConfigPath
                )
            ),
            (Self.kotlinPath, Self.kotlin(sources.screens)),
        ]
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

    static func kotlin(_ screens: [Screen]) -> String {
        let imports = screens.map { "import com.example.regzaremote.core.\($0.action)\nimport com.example.regzaremote.core.\($0.state)\n" }
        let invokes = screens.map { "\n    /** \($0.viewModel) に送る */\n    operator fun invoke(action: \($0.action))\n" }
        let overrides = screens.map { "\n    override fun invoke(action: \($0.action)) = app.send\($0.action)(action)" }
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

            \(imports.joined())import com.example.regzaremote.core.AppRoute
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

            /** 画面から操作を送る先。アプリ全体の操作も、画面ごとの操作も send(...) で送る */
            interface Send {\(invokes.joined())}

            /** Swift の窓口 (RegzaAndroidApp) に送る */
            class AppSend(private val app: RegzaAndroidApp) : Send {\(overrides.joined())
            }
            \(flows.joined())
            /** 振る舞いのテストの Android 側の相手: 道の ViewModel の型ごとに、約束事の操作をアプリと同じ道 (send) で送る。送れなければ false */
            suspend fun RegzaAndroidApp.contractSend(type: String, path: String, action: String, arguments: String): Boolean {
                val send = AppSend(this)
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
