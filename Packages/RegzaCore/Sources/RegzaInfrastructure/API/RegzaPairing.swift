import Foundation
import RegzaDomain

/// テレビに表示される PIN でアプリを登録する (レグザAppsコネクト v2)。
///
/// 1. `start()` で `POST /v2/public/request_connection` を送ると、テレビに PIN が表示され、
///    暗号化されたパスワードと salt が返る
/// 2. `confirm(pin:)` で PIN からパスワードを復号し、その資格情報の Digest 認証で
///    `POST /v2/remote/confirm_connection` を送ると登録が確定する
public actor RegzaPairing {
    public nonisolated let host: String
    public nonisolated let user: String
    private let client: RegzaClient
    private var challenge: Challenge?

    struct Challenge: Decodable, Equatable {
        let status: Int
        /// 16 進文字列
        let password: String?
        let salt: String?
    }

    /// - Parameter user: テレビに登録するユーザー ID。MAC アドレス形式 (`AA-BB-CC-DD-EE-FF`)
    public init(host: String, user: String = PairingUserID.make()) {
        self.host = host
        self.user = user
        client = RegzaClient(connection: RegzaConnection(host: host, user: user))
    }

    /// テレビに PIN を表示させる
    public func start() async throws {
        let data = try await client.post(path: "/v2/public/request_connection", form: ["user_id": user])
        guard let challenge = try? JSONDecoder().decode(Challenge.self, from: data) else {
            throw RegzaError.unsupported
        }
        guard challenge.status == 0 else { throw RegzaError.commandRejected(String(challenge.status)) }
        self.challenge = challenge
    }

    /// PIN で登録を確定し、保存すべき接続情報を返す
    public func confirm(pin: String) async throws -> RegzaConnection {
        guard let challenge, let encrypted = challenge.password, let salt = challenge.salt else {
            throw RegzaError.notConfigured
        }
        guard let password = Self.decryptPassword(encrypted, pin: pin, salt: salt) else {
            throw RegzaError.invalidPIN
        }
        let connection = RegzaConnection(host: host, user: user, password: password)
        await client.update(connection: connection)
        let data: Data
        do {
            data = try await client.post(path: "/v2/remote/confirm_connection", form: [:])
        } catch RegzaError.unauthorized {
            throw RegzaError.invalidPIN
        }
        let status = (try? JSONDecoder().decode(Challenge.self, from: data))?.status
        guard status == 0 else { throw RegzaError.commandRejected(status.map(String.init) ?? "?") }
        return connection
    }

    /// テレビの PIN 表示を取り消す
    public func cancel() async {
        guard challenge != nil else { return }
        challenge = nil
        _ = try? await client.post(path: "/v2/public/cancel_connection", form: ["user_id": user])
    }

    /// 鍵は PBKDF2-HMAC-SHA1 (PIN, salt, 1331 回) の先頭 16 バイト、AES-128-CBC (IV はゼロ) で復号する
    static func decryptPassword(_ hex: String, pin: String, salt: String) -> String? {
        guard let encrypted = [UInt8](hex: hex) else { return nil }
        let key = SHA1.pbkdf2(
            password: Array(pin.trimmingCharacters(in: .whitespaces).utf8),
            salt: Array(salt.utf8), iterations: 1331, length: 16
        )
        guard let plain = AES128(key: key)?.decryptCBC(encrypted),
              let password = String(bytes: plain, encoding: .ascii),
              !password.isEmpty, password.allSatisfy({ $0.isASCII && !$0.isNewline })
        else { return nil }
        return password
    }
}

extension [UInt8] {
    init?(hex: String) {
        let characters = [Character](hex.trimmingCharacters(in: .whitespacesAndNewlines))
        guard characters.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[i...i + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        self = bytes
    }
}
