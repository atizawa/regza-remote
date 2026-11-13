import Android
import CBoringSSL
import Foundation
import RegzaAndroidBridge
import RegzaApp

/// OS 固有の通信を明示してアプリを組み立てる。
public func regzaAppFactory() -> RegzaAndroidAppFactory {
    RegzaAndroidAppFactory(httpTransport: SocketTransport(tls: BoringSSLProvider()))
}

/// Android の実行環境のテストから、アプリと同じ SocketTransport で Bionic のソケットを通して HTTP を送る。
/// 外のサーバーには頼らず、テストが端末内に立てたサーバーへ送るための小さな診断口。
public func regzaAndroidNetworkProbe(_ address: String) async -> String {
    await networkProbe(address, tls: BoringSSLProvider())
}

/// 端末内の TLS テスト用。指定した証明書だけをこの接続の信頼先とし、アプリの信頼設定は変更しない。
public func regzaAndroidTLSProbe(_ address: String, _ certificatePath: String) async -> String {
    await networkProbe(address, tls: BoringSSLProvider(certificatePaths: [certificatePath]))
}

private func networkProbe(_ address: String, tls: BoringSSLProvider) async -> String {
    guard let url = URL(string: address) else { return "error: URL が正しくありません" }
    do {
        let response = try await SocketTransport(tls: tls).send(HTTPRequest(url: url, timeout: 5))
        return "\(response.statusCode)\n\(String(decoding: response.body, as: UTF8.self))"
    } catch {
        return "error: \(error)"
    }
}

/// APK の BoringSSL が初期化でき、Android のシステム CA を検証用コンテキストへ読み込めることを確かめる
public func regzaAndroidTLSIsReady() -> Bool {
    BoringSSLProvider().isReady
}

/// BoringSSL で TLS の接続を作る。証明書は Android が信頼している認証局で確かめる
/// (テレビの HTTPS は自己署名なので、SocketTransport が確かめないように頼む)
final class BoringSSLProvider: TLSProvider, @unchecked Sendable {
    /// 接続ごとの SSL を作る元。BoringSSL の SSL_CTX は複数のスレッドから使える
    private let unverified: OpaquePointer?
    private let lock = NSLock()
    /// 認証局の証明書を読み込んだもの。読み込みに時間がかかるので、初めて使うときに作る
    private var verifying: OpaquePointer?
    private let certificatePaths: [String]?

    init(certificatePaths: [String]? = nil) {
        self.certificatePaths = certificatePaths
        unverified = Self.makeContext(verifies: false)
    }

    /// 証明書を確かめない接続と、Android のシステム CA を使う接続の両方を作れる
    var isReady: Bool {
        unverified != nil && verifyingContext() != nil
    }

    deinit {
        SSL_CTX_free(unverified)
        if let verifying { SSL_CTX_free(verifying) }
    }

    func wrap(_ socket: SocketStream, host: String, verifiesCertificate: Bool) throws -> any ByteStream {
        let context = verifiesCertificate ? verifyingContext() : unverified
        guard let context, let ssl = SSL_new(context) else { throw RegzaError.network("暗号化の準備ができません") }
        let stream = TLSStream(ssl: ssl, socket: socket)
        do {
            guard SSL_set_fd(ssl, socket.descriptor) == 1 else { throw RegzaError.network("暗号化の準備ができません") }
            if verifiesCertificate {
                // URL の host は IPv6 なら [ ] で囲まれていることがある
                let name = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if Self.isIPAddress(name) {
                    // アドレスで接続するときは、証明書にそのアドレスが載っているかを確かめる
                    guard X509_VERIFY_PARAM_set1_ip_asc(SSL_get0_param(ssl), name) == 1 else {
                        throw RegzaError.network("暗号化の準備ができません")
                    }
                } else {
                    // 名前で接続するときは、名前を伝え (SNI)、証明書がその名前のものかを確かめる
                    guard SSL_set_tlsext_host_name(ssl, name) == 1, SSL_set1_host(ssl, name) == 1 else {
                        throw RegzaError.network("暗号化の準備ができません")
                    }
                }
            }
            do {
                // 確かめる設定 (SSL_VERIFY_PEER) なら、証明書が確かめられないと SSL_connect が失敗する
                try stream.retrying { SSL_connect(ssl) }
            } catch {
                if verifiesCertificate, SSL_get_verify_result(ssl) != X509_V_OK {
                    throw RegzaError.network("\(host) の証明書を確かめられませんでした")
                }
                throw error
            }
        } catch {
            stream.close()
            throw error
        }
        return stream
    }

    private func verifyingContext() -> OpaquePointer? {
        lock.lock()
        defer { lock.unlock() }
        if verifying == nil {
            verifying = Self.makeContext(verifies: true, certificatePaths: certificatePaths ?? Self.trustedCertificatePaths())
        }
        return verifying
    }

    private static func makeContext(verifies: Bool, certificatePaths: [String] = []) -> OpaquePointer? {
        guard let context = SSL_CTX_new(TLS_client_method()) else { return nil }
        _ = SSL_CTX_set_min_proto_version(context, UInt16(TLS1_2_VERSION))
        SSL_CTX_set_verify(context, verifies ? SSL_VERIFY_PEER : SSL_VERIFY_NONE, nil)
        if verifies {
            var loaded = false
            for path in certificatePaths {
                if SSL_CTX_load_verify_locations(context, path, nil) == 1 { loaded = true }
            }
            guard loaded else {
                SSL_CTX_free(context)
                return nil
            }
        }
        return context
    }

    /// Android が信頼している認証局の証明書のファイル。Android 14 からは更新できる場所 (APEX) にある。
    /// 利用者が設定で無効にしたものは除く (アプリは既定で利用者が足した認証局を信頼しないので、足したものは読まない)
    static func trustedCertificatePaths() -> [String] {
        let files = FileManager.default
        let directory = ["/apex/com.android.conscrypt/cacerts", "/system/etc/security/cacerts"]
            .first { (try? files.contentsOfDirectory(atPath: $0).isEmpty) == false }
        guard let directory, let names = try? files.contentsOfDirectory(atPath: directory) else { return [] }
        let user = getuid() / 100_000
        let removed = Set((try? files.contentsOfDirectory(atPath: "/data/misc/user/\(user)/cacerts-removed")) ?? [])
        return names.filter { !removed.contains($0) }.sorted().map { "\(directory)/\($0)" }
    }

    static func isIPAddress(_ host: String) -> Bool {
        var address = in6_addr()
        return inet_pton(AF_INET, host, &address) == 1 || inet_pton(AF_INET6, host, &address) == 1
    }
}

/// 暗号化した読み書き。ソケットはブロックしないので、BoringSSL が待ちを求めたら SocketStream で待つ
final class TLSStream: ByteStream {
    private let ssl: OpaquePointer
    private let socket: SocketStream
    private var isClosed = false

    init(ssl: OpaquePointer, socket: SocketStream) {
        self.ssl = ssl
        self.socket = socket
    }

    deinit { close() }

    /// 読み書きの準備ができるまで待ちながら繰り返す。成功したら結果 (正の数) を返す。相手が閉じたら 0
    @discardableResult
    func retrying(_ operation: () -> Int32) throws -> Int {
        while true {
            let result = operation()
            if result > 0 { return Int(result) }
            switch SSL_get_error(ssl, result) {
            case SSL_ERROR_WANT_READ: try socket.wait(for: .read)
            case SSL_ERROR_WANT_WRITE: try socket.wait(for: .write)
            // 相手が TLS の終わりを送ってきた、または TLS の終わりなしに接続を閉じた
            case SSL_ERROR_ZERO_RETURN: return 0
            case SSL_ERROR_SYSCALL where result == 0: return 0
            default: throw RegzaError.network("暗号化した通信に失敗しました")
            }
        }
    }

    func write(_ bytes: [UInt8]) throws {
        var offset = 0
        while offset < bytes.count {
            let written = try bytes[offset...].withUnsafeBytes { chunk in
                try retrying { SSL_write(ssl, chunk.baseAddress, Int32(chunk.count)) }
            }
            guard written > 0 else { throw RegzaError.network("送れませんでした") }
            offset += written
        }
    }

    func read(into buffer: inout [UInt8]) throws -> Int {
        try buffer.withUnsafeMutableBytes { target in
            try retrying { SSL_read(ssl, target.baseAddress, Int32(target.count)) }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        // 待たずに TLS の終わりを送るだけにする (返事は待たない)
        _ = SSL_shutdown(ssl)
        SSL_free(ssl)
        socket.close()
    }
}
