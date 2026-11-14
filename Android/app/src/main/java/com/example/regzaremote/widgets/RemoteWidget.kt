package com.example.regzaremote.widgets

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.example.regzaremote.MainActivity
import com.example.regzaremote.R
import com.example.regzaremote.core.RegzaKey

/** iOSと同じ中・大のリモコン。サイズ変更ではボタンの種類や並びを変えない。 */
abstract class RemoteWidget(private val large: Boolean) : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { RemoteWidgetContent(large) }
    }
}

class MediumRemoteWidget : RemoteWidget(large = false)
class LargeRemoteWidget : RemoteWidget(large = true)

private val LocalWidgetScale = staticCompositionLocalOf { 1f }

@Composable
private fun RemoteWidgetContent(large: Boolean) {
    val available = LocalSize.current
    val aspectRatio = if (large) 300f / 360f else 2f
    val width = minOf(available.width, available.height * aspectRatio)
    val height = width / aspectRatio
    // ランチャーのセルが縦長でも、見本と同じ本体の縦横比を保つ。
    CompositionLocalProvider(LocalWidgetScale provides (width.value / 300f).coerceAtMost(1f)) {
        Box(GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            RemoteWidgetBody(large, GlanceModifier.width(width).height(height))
        }
    }
}

@Composable
private fun RemoteWidgetBody(large: Boolean, modifier: GlanceModifier) {
    val scale = LocalWidgetScale.current
    Column(
        modifier.background(ImageProvider(R.drawable.widget_remote_background)).padding((6 * scale).dp)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        if (large) {
            Row(GlanceModifier.fillMaxWidth().height((30 * scale).dp)) {
                WidgetKey(RegzaKey.power(), GlanceModifier.defaultWeight(), compact = true)
                Spacer(GlanceModifier.defaultWeight())
                WidgetKey(RegzaKey.input(), GlanceModifier.defaultWeight(), compact = true)
                Spacer(GlanceModifier.width((6 * scale).dp))
                WidgetKey(RegzaKey.mute(), GlanceModifier.defaultWeight(), compact = true)
            }
            Spacer(GlanceModifier.height((6 * scale).dp))
            KeyRow(listOf(RegzaKey.terrestrial(), RegzaKey.bs(), RegzaKey.cs()), GlanceModifier.height((30 * scale).dp), compact = true)
            Spacer(GlanceModifier.height((6 * scale).dp))
            Column(GlanceModifier.defaultWeight()) {
                for (row in 0..3) {
                    if (row > 0) Spacer(GlanceModifier.height((6 * scale).dp))
                    KeyRow(
                        (1..3).map { column -> RegzaKey.`init`("num${row * 3 + column}").get() },
                        GlanceModifier.defaultWeight(),
                        numbers = true,
                    )
                }
            }
            Spacer(GlanceModifier.height((6 * scale).dp))
            KeyRow(
                listOf(RegzaKey.volumeDown(), RegzaKey.volumeUp(), RegzaKey.channelDown(), RegzaKey.channelUp()),
                GlanceModifier.height((40 * scale).dp).background(ImageProvider(R.drawable.widget_remote_band)).padding((5 * scale).dp),
                onBand = true,
            )
            Spacer(GlanceModifier.height((6 * scale).dp))
            KeyRow(
                listOf(RegzaKey.skipBackward(), RegzaKey.play(), RegzaKey.pause(), RegzaKey.skipForward()),
                GlanceModifier.height((30 * scale).dp),
                compact = true,
            )
        } else {
            KeyRow(listOf(RegzaKey.power(), RegzaKey.input(), RegzaKey.mute()), GlanceModifier.defaultWeight(), gap = 8)
            Spacer(GlanceModifier.height((8 * scale).dp))
            KeyRow(
                listOf(RegzaKey.channelDown(), RegzaKey.channelUp(), RegzaKey.volumeDown(), RegzaKey.volumeUp()),
                GlanceModifier.defaultWeight(),
                gap = 8,
            )
        }
    }
}

@Composable
private fun KeyRow(
    keys: List<RegzaKey>,
    modifier: GlanceModifier,
    compact: Boolean = false,
    numbers: Boolean = false,
    onBand: Boolean = false,
    gap: Int = 6,
) {
    Row(modifier.fillMaxWidth()) {
        keys.forEachIndexed { index, key ->
            if (index > 0) Spacer(GlanceModifier.width((gap * LocalWidgetScale.current).dp))
            WidgetKey(key, GlanceModifier.defaultWeight(), compact, numbers, onBand)
        }
    }
}

@Composable
private fun WidgetKey(
    key: RegzaKey,
    modifier: GlanceModifier,
    compact: Boolean = false,
    numbers: Boolean = false,
    onBand: Boolean = false,
) {
    val scale = LocalWidgetScale.current
    val name = key.rawValue
    val background = when {
        name == "power" -> if (compact) R.drawable.widget_power_compact else R.drawable.widget_power_key
        onBand -> R.drawable.widget_black_key
        compact -> R.drawable.widget_gray_compact
        else -> R.drawable.widget_gray_key
    }
    val foreground = ColorProvider(if (name == "power" || onBand) android.R.color.white else android.R.color.black)
    Box(
        modifier.fillMaxHeight().background(ImageProvider(background))
            .clickable(actionRunCallback<SendRemoteKeyAction>(actionParametersOf(SendRemoteKeyAction.KEY to name)))
            .semantics { contentDescription = key.label },
        contentAlignment = Alignment.Center,
    ) {
        val icon = when (name) {
            "power" -> R.drawable.widget_key_power
            "input" -> R.drawable.widget_key_input
            "mute" -> R.drawable.widget_key_mute
            "volumeDown" -> R.drawable.widget_key_volume_down
            "volumeUp" -> R.drawable.widget_key_volume_up
            "skipBackward" -> R.drawable.widget_key_replay
            "skipForward" -> R.drawable.widget_key_forward
            "play" -> R.drawable.widget_key_play
            "pause" -> R.drawable.widget_key_pause
            else -> null
        }
        if (icon != null) {
            Box(GlanceModifier.size(((if (compact || onBand) 20 else 24) * scale).dp), contentAlignment = Alignment.Center) {
                Image(
                    ImageProvider(icon),
                    contentDescription = null,
                    modifier = GlanceModifier.fillMaxSize(),
                    colorFilter = ColorFilter.tint(foreground),
                )
                if (name == "skipBackward" || name == "skipForward") {
                    Text(
                        if (name ==
                            "skipBackward"
                        ) {
                            "10"
                        } else {
                            "30"
                        },
                        style = TextStyle(color = foreground, fontSize = (8 * scale).sp, fontWeight = FontWeight.Bold),
                    )
                }
            }
        } else {
            val label = when (name) {
                "channelDown" -> "CH−"
                "channelUp" -> "CH＋"
                else -> key.label
            }
            Text(
                label,
                style = TextStyle(
                    color = foreground,
                    fontSize = (
                        (
                            if (numbers) {
                                24
                            } else if (compact || onBand) {
                                12
                            } else {
                                16
                            }
                            ) * scale
                        ).sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
        }
    }
}
