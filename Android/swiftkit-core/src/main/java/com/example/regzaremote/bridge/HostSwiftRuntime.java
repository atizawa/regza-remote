package com.example.regzaremote.bridge;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.FutureTask;

/** ホスト JVM 用の Swift 初期化。Android 端末では Looper に MainActor を接続する。 */
public final class HostSwiftRuntime {
    private HostSwiftRuntime() {}

    public static void loadLibraries(Runnable loadLibraries) {
        if (!System.getProperty("os.name").startsWith("Linux")) {
            loadLibraries.run();
            return;
        }
        // Linux の libdispatch は、初期化したスレッドに main queue を結び付ける。
        // そのスレッドを終了させると通常の直列キューになり、JVM の入力待ちや
        // Future.get() が MainActor を止めなくなる。処理の完了だけでなく終了まで待つ。
        FutureTask<Void> loading = new FutureTask<>(loadLibraries, null);
        Thread loader = new Thread(loading, "regza-swift-loader");
        loader.start();
        try {
            loader.join();
            loading.get();
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Swift の初期化が中断されました", exception);
        } catch (ExecutionException exception) {
            throw new IllegalStateException("Swift のライブラリを読み込めません", exception.getCause());
        }
    }
}
