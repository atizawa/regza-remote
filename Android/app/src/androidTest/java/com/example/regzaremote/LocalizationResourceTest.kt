package com.example.regzaremote

import android.content.res.Configuration
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.appservices.AndroidStrings
import com.example.regzaremote.core.RegzaAndroidBridge
import com.example.regzaremote.core.RegzaAndroidStrings
import com.example.regzaremote.core.RegzaKey
import java.util.Locale
import java.util.Optional
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** xcstringsから生成したXMLをAndroid標準リソースとして読み込む。 */
@RunWith(AndroidJUnit4::class)
class LocalizationResourceTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

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

    /** 共有の Swift が画面に出す文言は、アプリの起動時に入れた Android の文字列リソースから引き、入れていないキーは元言語にする */
    @Test
    fun sharedSwiftStringsComeFromAndroidResources() {
        assertEquals(context.getString(R.string.core_key_power), RegzaKey.power().label)
        val replaced = object : RegzaAndroidStrings {
            override fun text(key: String): Optional<String> = Optional.ofNullable(if (key == "core_key_power") "Power" else null)
        }
        try {
            instrumentation.runOnMainSync { RegzaAndroidBridge.regzaUseStrings(replaced) }
            assertEquals("Power", RegzaKey.power().label)
            assertEquals("消音", RegzaKey.mute().label)
        } finally {
            instrumentation.runOnMainSync { AndroidStrings.install(context) }
        }
        assertEquals(context.getString(R.string.core_key_power), RegzaKey.power().label)
    }
}
