package com.example.regzaremote.appservices

import android.content.Context
import com.example.regzaremote.core.RegzaAndroidBridge
import com.example.regzaremote.core.RegzaAndroidStrings
import com.example.regzaremote.localization.CoreStringResources
import java.util.Optional

/**
 * 共有の Swift が画面に出す文言 (RegzaAndroidStrings) の Android での実装。String Catalog から作った文字列リソースを、
 * 選ばれている言語で返す (iOS の Bundle にあたる)。書式の引数は %1$s などのまま返し、引数は Swift が入れる
 */
class AndroidStrings(private val context: Context) : RegzaAndroidStrings {
    override fun text(key: String): Optional<String> = Optional.ofNullable(CoreStringResources.ids[key]?.let(context::getString))

    companion object {
        /** 共有の Swift に、いまの言語の文言を入れる。起動時と、言語が変わったときに、メインスレッドから呼ぶ */
        fun install(context: Context) {
            RegzaAndroidBridge.regzaUseStrings(AndroidStrings(context))
        }
    }
}
