package com.example.regzaremote

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ExperimentalGlanceApi
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.compose
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.appservices.storage.AndroidStorage
import com.example.regzaremote.widgets.LargeRemoteWidget
import com.example.regzaremote.widgets.MediumRemoteWidget
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@OptIn(ExperimentalGlanceApi::class)
@RunWith(AndroidJUnit4::class)
class RemoteWidgetTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun pickerOffersMediumAndLargeAsSeparateWidgets() {
        val providers = AppWidgetManager.getInstance(context).installedProviders.filter { it.provider.packageName == context.packageName }
        assertEquals(setOf("リモコン（中）", "リモコン（大）"), providers.map { it.loadLabel(context.packageManager) }.toSet())
        assertEquals(2, providers.size)
        assertEquals("2種類にそれぞれのプレビューがある", 2, providers.map { it.previewImage }.toSet().size)
    }

    @Test
    fun layoutsFollowIOSFamiliesAndKeepTheirKeysAfterResizing() = runBlocking {
        val mediumKeys = listOf("電源", "入力切替", "消音", "チャンネル−", "チャンネル＋", "音量−", "音量＋")
        val largeKeys = listOf("電源", "入力切替", "消音", "地デジ", "BS", "CS") +
            (1..12).map(Int::toString) + listOf("音量−", "音量＋", "チャンネル−", "チャンネル＋", "10秒戻し", "再生", "一時停止", "30秒送り")
        val medium = render(MediumRemoteWidget(), DpSize(300.dp, 150.dp), "remote_widget_medium_preview")
        val large = render(LargeRemoteWidget(), DpSize(300.dp, 360.dp), "remote_widget_large_preview")
        val minimumMedium = render(MediumRemoteWidget(), DpSize(250.dp, 110.dp))
        val minimumLarge = render(LargeRemoteWidget(), DpSize(250.dp, 250.dp))
        assertEquals(mediumKeys, keyLabels(medium))
        assertEquals(mediumKeys, keyLabels(minimumMedium))
        assertEquals(largeKeys, keyLabels(large))
        assertEquals(largeKeys, keyLabels(minimumLarge))
        val tallMedium = render(MediumRemoteWidget(), DpSize(300.dp, 360.dp))
        val tallLarge = render(LargeRemoteWidget(), DpSize(300.dp, 500.dp))
        assertEquals(mediumKeys, keyLabels(tallMedium))
        assertEquals(largeKeys, keyLabels(tallLarge))
        withContext(Dispatchers.Main) {
            for (widget in listOf(medium, minimumMedium, large, minimumLarge)) {
                for (label in keyLabels(widget)) {
                    val button = button(widget, label)
                    val bounds = Rect()
                    button.getDrawingRect(bounds)
                    (widget as ViewGroup).offsetDescendantRectToMyCoords(button, bounds)
                    assertTrue(
                        "ボタンが表示範囲に収まる: $label",
                        bounds.left >= 0 && bounds.top >= 0 && bounds.right <= widget.width && bounds.bottom <= widget.height,
                    )
                    assertTrue("ボタンに大きさがある: $label", bounds.width() > 0 && bounds.height() > 0)
                }
            }
            assertTrue("大は数字を主役にする", button(large, "1").height > button(large, "電源").height)
            assertEquals("中は縦に引き伸ばさない", button(medium, "電源").height, button(tallMedium, "電源").height)
            assertEquals("大は縦に引き伸ばさない", button(large, "1").height, button(tallLarge, "1").height)
        }
    }

    @Test
    fun clickingWidgetKeyUsesSavedCredentialsAndWaitsForDigestRequest() = runBlocking {
        val preferences = context.getSharedPreferences("regza", Context.MODE_PRIVATE)
        val saved = preferences.all
        try {
            MockWebServer().use { server ->
                server.enqueue(
                    MockResponse.Builder().code(401)
                        .addHeader("WWW-Authenticate", "Digest realm=\"REGZA\", nonce=\"widget-test\", qop=\"auth\"")
                        .build(),
                )
                server.enqueue(MockResponse.Builder().body("0").build())
                server.start()
                val storage = AndroidStorage(context)
                storage.setValue(server.url("/").toString(), "host")
                storage.setValue("widget-user", "user")
                storage.setValue("widget-password", "password")
                storage.setValue("42", "ownStreamIDs")
                storage.setValue(server.url("/").toString(), "streamHost")

                val widget = render(MediumRemoteWidget(), DpSize(250.dp, 150.dp))
                withContext(Dispatchers.Main) {
                    assertTrue(button(widget, "音量＋").performClick())
                }
                val challenge = server.takeRequest(10, TimeUnit.SECONDS)
                val authorized = server.takeRequest(10, TimeUnit.SECONDS)
                assertNotNull("Glanceのボタンからキー送信に到達する", challenge)
                assertNotNull("Digest認証後にキーを送信する", authorized)
                assertEquals("/remote/remote.htm?key=40BF1A", authorized!!.target)
                assertTrue(authorized.headers["Authorization"]!!.contains("username=\"widget-user\""))
                assertEquals(2, server.requestCount)
                assertEquals("42", preferences.getString("ownStreamIDs", null))
            }
        } finally {
            preferences.edit().clear().apply {
                saved.forEach { (key, value) -> putString(key, value as String) }
            }.commit()
        }
    }

    private suspend fun render(widget: GlanceAppWidget, size: DpSize, previewName: String? = null): View {
        val remoteViews = widget.compose(context, size = size)
        return withContext(Dispatchers.Main) {
            val root = remoteViews.apply(context, FrameLayout(context))
            val density = context.resources.displayMetrics.density
            val width = (size.width.value * density).toInt()
            val height = (size.height.value * density).toInt()
            root.measure(
                View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
            )
            root.layout(0, 0, width, height)
            // プレビュー更新時だけ、本番と同じ描画結果を画像として取り出す。
            if (previewName != null && InstrumentationRegistry.getArguments().getString("exportWidgetPreviews") == "true") {
                val directory = context.filesDir.resolve("widget-previews").apply { mkdirs() }
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                root.draw(Canvas(bitmap))
                directory.resolve("$previewName.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                bitmap.recycle()
            }
            root
        }
    }

    private fun keyLabels(view: View): List<String> = allViews(view).mapNotNull {
        it.contentDescription?.toString()
    }.filter { it.isNotEmpty() }

    private fun button(root: View, label: String): View {
        var button: View = allViews(root).single { it.contentDescription?.toString() == label }
        while (!button.isClickable) button = button.parent as View
        return button
    }

    private fun allViews(view: View): List<View> =
        listOf(view) + if (view is ViewGroup) (0 until view.childCount).flatMap { allViews(view.getChildAt(it)) } else emptyList()
}
