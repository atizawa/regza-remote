package com.example.regzaremote.widgets

import android.content.ComponentName
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
import androidx.glance.LocalContext
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
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.design.R as DesignR
import com.example.regzaremote.systemactions.SendRemoteKeyAction

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
    val bodyModifier = when {
        width == available.width && height == available.height -> GlanceModifier.fillMaxSize()
        width == available.width -> GlanceModifier.fillMaxWidth().height(height)
        height == available.height -> GlanceModifier.fillMaxHeight().width(width)
        else -> GlanceModifier.width(width).height(height)
    }
    // ランチャーのセルが縦長でも、見本と同じ本体の縦横比を保つ。
    CompositionLocalProvider(LocalWidgetScale provides (width.value / 300f).coerceAtMost(1f)) {
        Box(
            GlanceModifier.fillMaxSize()
                .background(ImageProvider(R.drawable.widget_remote_background))
                // 押したらアプリを開く。起動の画面はアプリ本体にあるので、OS に登録した起動の入口 (ランチャーから開くのと同じもの) を使う
                .clickable(actionStartActivity(launcherActivity(LocalContext.current))),
            contentAlignment = Alignment.Center,
        ) {
            RemoteWidgetBody(large, bodyModifier.padding((6 * LocalWidgetScale.current).dp))
        }
    }
}

@Composable
private fun RemoteWidgetBody(large: Boolean, modifier: GlanceModifier) {
    val scale = LocalWidgetScale.current
    Column(
        modifier,
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
                        numberKeys.subList(row * 3, row * 3 + 3),
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
    val kind = key.discriminator
    val background = when {
        kind == RegzaKey.Discriminator.POWER -> if (compact) R.drawable.widget_power_compact else R.drawable.widget_power_key
        onBand -> R.drawable.widget_black_key
        compact -> R.drawable.widget_gray_compact
        else -> R.drawable.widget_gray_key
    }
    val foreground = ColorProvider(if (kind == RegzaKey.Discriminator.POWER || onBand) android.R.color.white else android.R.color.black)
    Box(
        modifier.fillMaxHeight().background(ImageProvider(background))
            .clickable(actionRunCallback<SendRemoteKeyAction>(actionParametersOf(SendRemoteKeyAction.KEY to name)))
            .semantics { contentDescription = key.label },
        contentAlignment = Alignment.Center,
    ) {
        val icon = when (kind) {
            RegzaKey.Discriminator.POWER -> DesignR.drawable.widget_key_power
            RegzaKey.Discriminator.INPUT -> DesignR.drawable.widget_key_input
            RegzaKey.Discriminator.MUTE -> DesignR.drawable.widget_key_mute
            RegzaKey.Discriminator.VOLUMEDOWN -> DesignR.drawable.widget_key_volume_down
            RegzaKey.Discriminator.VOLUMEUP -> DesignR.drawable.widget_key_volume_up
            RegzaKey.Discriminator.SKIPBACKWARD -> DesignR.drawable.widget_key_replay
            RegzaKey.Discriminator.SKIPFORWARD -> DesignR.drawable.widget_key_forward
            RegzaKey.Discriminator.PLAY -> DesignR.drawable.widget_key_play
            RegzaKey.Discriminator.PAUSE -> DesignR.drawable.widget_key_pause
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
                if (kind == RegzaKey.Discriminator.SKIPBACKWARD || kind == RegzaKey.Discriminator.SKIPFORWARD) {
                    Text(
                        if (kind == RegzaKey.Discriminator.SKIPBACKWARD) "10" else "30",
                        style = TextStyle(color = foreground, fontSize = (8 * scale).sp, fontWeight = FontWeight.Bold),
                    )
                }
            }
        } else {
            val label = when (kind) {
                RegzaKey.Discriminator.CHANNELDOWN -> "CH−"
                RegzaKey.Discriminator.CHANNELUP -> "CH＋"
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

/** 大のリモコンの 1〜12 (3 列で 4 段) */
private val numberKeys = listOf(
    RegzaKey.num1(), RegzaKey.num2(), RegzaKey.num3(), RegzaKey.num4(), RegzaKey.num5(), RegzaKey.num6(),
    RegzaKey.num7(), RegzaKey.num8(), RegzaKey.num9(), RegzaKey.num10(), RegzaKey.num11(), RegzaKey.num12(),
)

/** OS に登録した起動の画面 (ランチャーから開くのと同じもの) */
private fun launcherActivity(context: Context): ComponentName =
    checkNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName)?.component)
