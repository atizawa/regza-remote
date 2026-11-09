package com.example.regzaremote

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.example.regzaremote.core.RegzaAndroid
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** テレビに登録した接続情報 */
data class Connection(val host: String, val user: String, val password: String)

/**
 * テレビの接続情報の保存 (iOS のキーチェーンに当たる)。
 * パスワードは Android Keystore の鍵で暗号化して SharedPreferences に置く。鍵は端末の外に出せない
 */
class ConnectionStore(context: Context) {
    private val preferences = context.getSharedPreferences("regza", Context.MODE_PRIVATE)

    fun load(): Connection? {
        val host = preferences.getString(HOST, null) ?: return null
        val user = preferences.getString(USER, null) ?: return null
        val password = preferences.getString(PASSWORD, null)?.let(::decrypt) ?: return null
        return Connection(host, user, password)
    }

    fun save(connection: Connection) {
        preferences.edit()
            .putString(HOST, connection.host)
            .putString(USER, connection.user)
            .putString(PASSWORD, encrypt(connection.password))
            .apply()
    }

    /** 番組表を読む Mirakurun のアドレス。未設定なら空 (パスワードではないので暗号化しない) */
    var guideHost: String
        get() = preferences.getString(GUIDE_HOST, null) ?: ""
        set(value) = preferences.edit().putString(GUIDE_HOST, value).apply()

    /** ライブ視聴に使う EPGStation のアドレス。未設定なら空 */
    var streamHost: String
        get() = preferences.getString(STREAM_HOST, null) ?: ""
        set(value) = preferences.edit().putString(STREAM_HOST, value).apply()

    /** このアプリが頼んだライブ視聴の配信の ID (「1,2」のようにつなぐ)。強制終了で止められなかった配信を、次に開いたときに止める */
    var ownStreamIDs: String
        get() = preferences.getString(OWN_STREAM_IDS, null) ?: ""
        set(value) = preferences.edit().putString(OWN_STREAM_IDS, value).apply()

    /**
     * PIN 登録に使うこのアプリ用のユーザー ID。無ければ作って保存する。
     * 登録し直すときも同じ ID を使うと、テレビ側で上書きされて登録が増えない。
     * ただし iOS のキーチェーンと違い、アプリを削除すると消える
     */
    fun pairingUserID(): String =
        preferences.getString(PAIRING_USER_ID, null)
            ?: RegzaAndroid.regzaMakeUserID().also { preferences.edit().putString(PAIRING_USER_ID, it).apply() }

    // MARK: Android Keystore

    private fun key(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    /** 先頭に IV を付けて Base64 にする */
    private fun encrypt(text: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key()) }
        return Base64.encodeToString(cipher.iv + cipher.doFinal(text.toByteArray()), Base64.NO_WRAP)
    }

    /** 鍵が消えた (端末の初期化の引き継ぎなど) ときは null にし、登録し直してもらう */
    private fun decrypt(encoded: String): String? = runCatching {
        val bytes = Base64.decode(encoded, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, IV_LENGTH))
        }
        String(cipher.doFinal(bytes, IV_LENGTH, bytes.size - IV_LENGTH))
    }.getOrNull()

    private companion object {
        const val HOST = "host"
        const val USER = "user"
        const val PASSWORD = "password"
        const val PAIRING_USER_ID = "pairingUserID"
        const val GUIDE_HOST = "guideHost"
        const val STREAM_HOST = "streamHost"
        const val OWN_STREAM_IDS = "ownStreamIDs"
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "regza.connection"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
    }
}
