package com.example.regzaremote

import com.example.regzaremote.core.RegzaAndroidStorage
import java.util.Optional

/** メモリに置くだけの保存先 (アプリの AndroidStorage の代わり) */
class MemoryStorage : RegzaAndroidStorage {
    val values = mutableMapOf<String, String>()
    override fun value(key: String): Optional<String> = Optional.ofNullable(values[key])
    override fun setValue(value: String, key: String) {
        values[key] = value
    }
}
