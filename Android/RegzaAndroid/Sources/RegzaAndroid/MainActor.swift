import Android
import CAndroidMainLoop

/// Android で Swift を使う準備。アプリの起動時 (Application.onCreate) に、メインスレッドから呼ぶ。
/// 通信をソケットで送るように差し替え (useSocketTransport)、Android のメインスレッドで Swift の MainActor を動かす。
///
/// MainActor の仕事は libdispatch の main queue に入るが、Android のメインスレッドは Looper で回っていて、
/// main queue を誰も片づけないので、そのままでは MainActor の仕事が動かずに止まる。
/// main queue に仕事が来ると libdispatch が書き込む eventfd を Looper に見張らせ、来たら片づける
public func regzaSetUpMainActor() {
    _ = useSocketTransport
    _ = mainActorOnLooper
}

private let mainActorOnLooper: Void = {
    guard let looper = ALooper_forThread() else {
        fatalError("regzaSetUpMainActor はメインスレッドから呼ぶ")
    }
    let result = ALooper_addFd(
        looper, _dispatch_get_main_queue_handle_4CF(), Int32(ALOOPER_POLL_CALLBACK), Int32(ALOOPER_EVENT_INPUT),
        { descriptor, _, _ in
            // 知らせの数を読んで空にしてから、溜まった仕事を片づける
            var count: UInt64 = 0
            _ = read(descriptor, &count, MemoryLayout<UInt64>.size)
            _dispatch_main_queue_callback_4CF(nil)
            // 見張りを続ける
            return 1
        },
        nil
    )
    precondition(result == 1, "Looper に main queue を見張らせられません")
}()
