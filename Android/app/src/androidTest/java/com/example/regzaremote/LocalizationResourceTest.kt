package com.example.regzaremote

import android.content.res.Configuration
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** xcstringsから生成したXMLをAndroid標準リソースとして読み込む。 */
@RunWith(AndroidJUnit4::class)
class LocalizationResourceTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun nativeResourcesPreserveArgumentsAndNewlines() {
        assertEquals("設定", context.getString(R.string.settings_title))
        assertEquals("Mirakurun & <TV> を探しています…", context.getString(R.string.server_searching, "Mirakurun & <TV>"))
        assertEquals("10:00から11:00", context.getString(R.string.program_time_range, "10:00", "11:00"))
        assertEquals("「番組 & ニュース」の予約を取り消しますか？", context.getString(R.string.reservation_cancel_confirmation, "番組 & ニュース"))
        assertTrue(context.getString(R.string.guide_setup_help).contains("\n設定画面"))
        assertTrue(context.getString(R.string.server_port_help, 40772).contains("40772"))
    }

    @Test
    fun untranslatedLocaleFallsBackToSourceLanguage() {
        val configuration = Configuration(context.resources.configuration).apply { setLocale(Locale.ENGLISH) }
        val english = context.createConfigurationContext(configuration)
        assertEquals("設定", english.getString(R.string.settings_title))
    }
}
