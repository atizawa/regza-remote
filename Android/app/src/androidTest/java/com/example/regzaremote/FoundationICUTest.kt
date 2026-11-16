package com.example.regzaremote

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

/**
 * APK の ICU (データを日本語・英語などに絞って作り直したもの。scripts/slim-icu-data.swift) で、アプリが頼っている日付・タイムゾーン・
 * 文字コード・正規化が、ICU をすべて持つ環境と同じ結果になること。期待する値は Swift の FoundationCheckTests と同じにする
 */
@RunWith(AndroidJUnit4::class)
class FoundationICUTest {
    @Test
    fun slimmedICUMatchesFullICU() {
        val expected = listOf(
            "timeZone: Asia/Tokyo 32400",
            "weekday: 6",
            "startOfDay: 1799938800",
            "time: 17:00",
            "day: 1月15日(金)",
            "searchDay: 1/15(金)",
            "dayShort: 15(金)",
            "shiftJIS: 日本語のテキスト",
            "nfkc: ガギ abc123 ひらがな(株)1abc",
            "nfc: ズ",
            "caseInsensitive: true",
            "trimming: テキスト",
        )
        val actual = FoundationCheck.run().lines()
        assertEquals(expected.size, actual.size)
        // 見た目が同じでも、空白の種類や濁点の付け方 (合成済みか、別の文字か) が違うことがあるので、違えば文字コードも出す
        expected.zip(actual).forEach { (want, got) -> assertEquals("${codePoints(want)}\n${codePoints(got)}", want, got) }
    }

    private fun codePoints(text: String) = text.codePoints().toArray().joinToString(" ") { "%04X".format(it) }
}

/** テスト専用の .so (libRegzaFoundationCheck。debug の APK にだけ入る) の入口 */
object FoundationCheck {
    init {
        System.loadLibrary("RegzaFoundationCheck")
    }

    external fun run(): String
}
