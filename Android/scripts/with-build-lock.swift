// 同じ生成ファイルを使う Android・ホスト JVM のビルドを、プロセスをまたいで直列化する。
// Android/ で .build を用意してから、実行するコマンドと引数を渡す。
#if os(Linux)
import Glibc
#else
import Darwin
#endif

let descriptor = open(".build/swift-build.lock", O_CREAT | O_RDWR, mode_t(0o600))
guard descriptor >= 0 else {
    perror("[build-swift] ロックファイルを開けません")
    exit(1)
}

if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
    guard errno == EWOULDBLOCK || errno == EAGAIN else {
        perror("[build-swift] ロックを取得できません")
        exit(1)
    }
    let message = "[build-swift] 別の Swift ビルドの完了を待っています。\n"
    message.withCString { pointer in
        _ = write(STDERR_FILENO, pointer, message.utf8.count)
    }
    while flock(descriptor, LOCK_EX) != 0 {
        if errno == EINTR { continue }
        perror("[build-swift] ロックを取得できません")
        exit(1)
    }
}

guard CommandLine.arguments.count > 1 else {
    fatalError("実行するコマンドを渡してください")
}
var arguments = CommandLine.arguments.dropFirst().map { strdup($0) }
arguments.append(nil)
// ロックの FD を継承したまま置き換える。終了コードとシグナルをそのまま扱い、
// 子プロセスも終了すると OS がロックを解放する。ロックファイル自体は削除しない。
arguments.withUnsafeMutableBufferPointer { buffer in
    _ = execvp(buffer[0]!, buffer.baseAddress!)
}
perror("[build-swift] コマンドを起動できません")
exit(1)
