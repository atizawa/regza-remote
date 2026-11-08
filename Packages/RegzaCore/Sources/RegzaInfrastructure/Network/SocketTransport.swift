import Foundation
import RegzaDomain
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#endif

/// ソケットで HTTP/1.1 を送る。Android の URLSession は返事を待つ間 CPU を使い続けるので、Android はこちらを使う。
/// 1 回ごとに接続し、送り終えたら閉じる。待つ間は自分のスレッドで止まって待ち、CPU を使わない。
/// HTTPS は `tls` を渡したときに使える。証明書は確かめるが、テレビの HTTPS のポート (`RegzaClient.securePort`) だけは
/// 自己署名の証明書なので確かめない (iOS 版の URLSessionTransport と同じ)
public final class SocketTransport: HTTPTransport {
    private let tls: (any TLSProvider)?

    public init(tls: (any TLSProvider)? = nil) {
        self.tls = tls
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let cancellation = Cancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // 待つ間は止まるので、Swift の並行処理のスレッドではなく専用のスレッドで送る
                let thread = Thread { [tls] in
                    do {
                        continuation.resume(returning: try Self.exchange(request, tls: tls, cancellation: cancellation))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                thread.start()
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func exchange(_ request: HTTPRequest, tls: (any TLSProvider)?, cancellation: Cancellation) throws -> HTTPResponse {
        guard let host = request.url.host, !host.isEmpty else { throw RegzaError.invalidHost }
        let secure = request.url.scheme == "https"
        let port = request.url.port ?? (secure ? 443 : 80)

        let socket = try SocketStream.connect(host: host, port: port, timeout: request.timeout, cancellation: cancellation)
        var stream: any ByteStream = socket
        defer { stream.close() }
        if secure {
            guard let tls else { throw RegzaError.network("HTTPS を使えません") }
            stream = try tls.wrap(socket, host: host, verifiesCertificate: port != RegzaClient.securePort)
        }

        try stream.write(HTTP1.encode(request))
        var parser = HTTP1.ResponseParser()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while parser.response == nil {
            let count = try stream.read(into: &buffer)
            if count == 0 { return try parser.finish() }
            try parser.append(buffer[..<count])
        }
        return parser.response!
    }
}

/// HTTPS の暗号化を外から渡す (Android は BoringSSL)
public protocol TLSProvider: Sendable {
    /// つながったソケットの上で TLS の接続の手続き (ハンドシェイク) をし、暗号化した読み書きを返す。
    /// `verifiesCertificate` なら、信頼できる認証局の証明書で、名前 (またはアドレス) が `host` と合うかを確かめる
    func wrap(_ socket: SocketStream, host: String, verifiesCertificate: Bool) throws -> any ByteStream
}

public protocol ByteStream: AnyObject {
    func write(_ bytes: [UInt8]) throws
    /// 読めた数を返す。相手が閉じたら 0
    func read(into buffer: inout [UInt8]) throws -> Int
    func close()
}

/// 取り消されたかを、送っているスレッドから見る
final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }
}

/// ブロックしないソケット。読み書きできるまで poll で待つ (待つ間は CPU を使わない)
public final class SocketStream: ByteStream {
    public let descriptor: Int32
    /// 返事が途切れてから諦めるまでの秒数
    let timeout: TimeInterval
    let cancellation: Cancellation
    private var isClosed = false

    private init(descriptor: Int32, timeout: TimeInterval, cancellation: Cancellation) {
        self.descriptor = descriptor
        self.timeout = timeout
        self.cancellation = cancellation
    }

    deinit { close() }

    static func connect(host: String, port: Int, timeout: TimeInterval, cancellation: Cancellation) throws -> SocketStream {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = socketStream
        var list: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &list) == 0, let first = list else {
            throw RegzaError.network("\(host) が見つかりません")
        }
        defer { freeaddrinfo(list) }

        var lastError = RegzaError.network("\(host) に接続できません")
        for info in sequence(first: first, next: { $0.pointee.ai_next }) {
            let descriptor = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
            guard descriptor >= 0 else { continue }
            let stream = SocketStream(descriptor: descriptor, timeout: timeout, cancellation: cancellation)
            _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL, 0) | O_NONBLOCK)
            #if canImport(Darwin)
            // 相手が閉じたあとに書いても SIGPIPE で落ちないようにする (Linux は送るときの MSG_NOSIGNAL)
            var on: Int32 = 1
            setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            #endif
            do {
                if connectSocket(descriptor, info.pointee.ai_addr, info.pointee.ai_addrlen) != 0 {
                    guard errno == EINPROGRESS else { throw RegzaError.network("\(host) に接続できません") }
                    try stream.wait(for: .write)
                    var error: Int32 = 0
                    var length = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &length)
                    guard error == 0 else { throw RegzaError.network("\(host) に接続できません") }
                }
                return stream
            } catch let error as RegzaError {
                lastError = error
                stream.close()
                if case .network(let message) = error, message == Self.timeoutMessage || message == Self.cancelledMessage {
                    throw error
                }
            }
        }
        throw lastError
    }

    public enum Readiness { case read, write }

    static let timeoutMessage = "テレビから返事がありません"
    static let cancelledMessage = "取り消しました"

    /// 読み書きできるようになるまで待つ。取り消しを見るため、短く区切って待つ
    public func wait(for readiness: Readiness) throws {
        let deadline = Date().addingTimeInterval(timeout)
        let events = Int16(truncatingIfNeeded: readiness == .read ? Int(POLLIN) : Int(POLLOUT))
        while true {
            if cancellation.isCancelled { throw RegzaError.network(Self.cancelledMessage) }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw RegzaError.network(Self.timeoutMessage) }
            var target = pollfd(fd: descriptor, events: events, revents: 0)
            let result = poll(&target, 1, Int32(min(remaining, 0.2) * 1000) + 1)
            if result > 0 { return }
            if result < 0 && errno != EINTR { throw RegzaError.network("通信できません (\(errno))") }
        }
    }

    public func write(_ bytes: [UInt8]) throws {
        var offset = 0
        while offset < bytes.count {
            let sent = bytes[offset...].withUnsafeBytes { sendBytes(descriptor, $0.baseAddress!, $0.count) }
            if sent > 0 {
                offset += sent
            } else if sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
                try wait(for: .write)
            } else {
                throw RegzaError.network("送れませんでした (\(errno))")
            }
        }
    }

    public func read(into buffer: inout [UInt8]) throws -> Int {
        while true {
            let count = buffer.withUnsafeMutableBytes { recv(descriptor, $0.baseAddress!, $0.count, 0) }
            if count >= 0 { return count }
            guard errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR else {
                throw RegzaError.network("受け取れませんでした (\(errno))")
            }
            try wait(for: .read)
        }
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        _ = closeSocket(descriptor)
    }
}

// MARK: - OS ごとの違い (SocketStream の connect・close と名前が重なる関数もここで呼ぶ)

#if canImport(Glibc)
private let socketStream = Int32(SOCK_STREAM.rawValue)
#else
private let socketStream = SOCK_STREAM
#endif

private func connectSocket(_ descriptor: Int32, _ address: UnsafeMutablePointer<sockaddr>!, _ length: socklen_t) -> Int32 {
    connect(descriptor, address, length)
}

/// 送る分は空にならない (Android の send は nil を受け付けない)
private func sendBytes(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    #if canImport(Darwin)
    send(descriptor, bytes, count, 0)
    #else
    send(descriptor, bytes, count, Int32(MSG_NOSIGNAL))
    #endif
}

private func closeSocket(_ descriptor: Int32) -> Int32 {
    close(descriptor)
}
