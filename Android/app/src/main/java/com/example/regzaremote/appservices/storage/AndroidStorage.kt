package com.example.regzaremote.appservices.storage

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.example.regzaremote.core.RegzaAndroidStorage
import java.security.KeyStore
import java.util.Optional
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Swift の保存先 (RegzaAndroidStorage) の Android での実装 (iOS のキーチェーンに当たる)。
 * 値は SharedPreferences に置き、パスワードは Android Keystore の鍵で暗号化する。鍵は端末の外に出せない。
 * どの値をいつ保存するかは Swift の Repository と StorageManager が決める
 */
class AndroidStorage(context: Context) : RegzaAndroidStorage {
    private val preferences = context.getSharedPreferences("regza", Context.MODE_PRIVATE)

    /** 鍵が消えて (端末の初期化の引き継ぎなど) パスワードを復号できないときも、無いことにする (登録し直してもらう) */
    override fun value(key: String): Optional<String> {
        val value = preferences.getString(key, null)
        return Optional.ofNullable(if (key == PASSWORD) value?.let(::decrypt) else value)
    }

    override fun setValue(value: String, key: String) {
        preferences.edit().putString(key, if (key == PASSWORD) encrypt(value) else value).apply()
    }

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
        /** 暗号化して置く値 (Swift の AndroidStorageKey.password) */
        const val PASSWORD = "password"
        const val KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "regza.connection"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH = 12
    }
}
