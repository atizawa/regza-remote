package com.example.regzaremote

import com.example.regzaremote.bridge.HostSwiftRuntime
import com.example.regzaremote.bridge.contractSend
import com.example.regzaremote.bridge.contractStateJSON
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaContractCommand
import java.io.File
import kotlin.system.exitProcess
import kotlinx.coroutines.future.await
import kotlinx.coroutines.runBlocking
import org.swift.swiftkit.core.SwiftLibraries

/**
 * 振る舞いのテスト (BehaviorTests) の Android 側の相手。regza と同じ約束事 (1 行ずつの命令と、返す JSON) を話す。
 * 命令の読み方と JSON の形は Swift の同じもの (IntrospectionSession) に任せ、操作を送るところと state を受け取るところだけを、
 * アプリと同じ道 (Kotlin の send と xxxStates → swift-java のつなぎ → 窓口 → 共有の ViewModel) で行う。
 * 見本の返事 (--sample) で組み立てるので、テレビにも録画サーバーにもつながない
 */
fun main(args: Array<String>): Unit = runBlocking {
    HostSwiftRuntime.loadLibraries { SwiftLibraries.loadLibraryWithFallbacks("RegzaAndroid") }
    if ("--sample" !in args) {
        System.err.println("--sample だけに対応しています")
        exitProcess(2)
    }
    // 見本の返事を差し替える fixture (regza と同じ --fixture <JSON のファイル>)
    val fixture = args.indexOf("--fixture").takeIf { it >= 0 }?.let { File(args[it + 1]).readText() } ?: ""
    val app = RegzaAndroidApp.sample(MemoryStorage(), fixture).orElse(null) ?: run {
        println("""{"error":"fixture を読めません"}""")
        exitProcess(1)
    }
    println("""{"ready":true}""")
    val input = System.`in`.bufferedReader()
    while (true) {
        val line = input.readLine() ?: break
        val command = app.contractParse(line).await().orElse(null) ?: continue
        val output = when (command.kind) {
            "quit" -> break
            "do" -> perform(app, command)
            "ls" -> list(app, command.path, idle = true)
            else -> app.contractRun(line).await()
        }
        println(output)
        System.out.flush()
    }
    exitProcess(0)
}

/** 操作を、アプリと同じ道で送り、通信などが終わるのを待ってから状態を返す (regza の do と同じ) */
private suspend fun perform(app: RegzaAndroidApp, command: RegzaContractCommand): String {
    app.contractCheck(command.path, command.action, command.arguments).await().orElse(null)?.let { return it }
    val type = app.contractTargetType(command.path).await().orElse(null) ?: return app.contractRun("ls ${command.path}").await()
    if (!app.contractSend(type, command.path, command.action, command.arguments)) {
        return """{"error":"$type の操作は Android の相手から送れません"}"""
    }
    val idle = app.contractWaitUntilIdle().await()
    // 閉じる操作などで、その ViewModel がなくなった
    app.contractClosed(command.path).await().orElse(null)?.let { return it }
    return list(app, command.path, idle)
}

/** 道の状態と操作の一覧。state はアプリと同じ道で受け取る (regza の ls と同じ形) */
private suspend fun list(app: RegzaAndroidApp, path: String, idle: Boolean): String {
    val type = app.contractTargetType(path).await().orElse(null) ?: return app.contractRun("ls $path").await()
    val route = app.contractTargetRoute(path).await().orElse(null)
    val state = app.contractStateJSON(type, route)
        ?: return """{"error":"$type の state は Android の相手から読めません"}"""
    return app.contractNode(path, state, idle).await()
}
