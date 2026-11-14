package com.example.regzaremote.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.remoteStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.RemoteState
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.DesignColors
import com.example.regzaremote.design.DesignDimensions
import com.example.regzaremote.design.RemoteBody
import com.example.regzaremote.localization.AppStrings
import com.example.regzaremote.ui.components.HeaderIconButton
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.components.verticalGradient
import com.example.regzaremote.ui.preview.SamplePreview

/**
 * リモコンの画面 (iOS 版の RemoteScreen と同じ並び・色)。
 * 実物のリモコンと同じく、電源 → 放送の種類と数字 → 十字キー・色ボタン → 再生 の順に並べる。
 * リモコンは手の感覚で押すので、再生中かどうかでボタンの位置を変えない
 * (再生と一時停止は同じ場所で入れ替える)。いま映っているものは、どのタブでも下のミニプレーヤーに出す
 */
@Composable
fun RemoteScreen(state: RemoteState, sendAction: Send) {
    val nowPlaying = state.nowPlaying.orElse(null)
    val press: (RegzaKey) -> Unit = { sendAction(RemoteAction.press(it)) }
    val band = state.nowPlayingBand.orElse(null)?.rawValue
    var isShowingMore by rememberSaveable { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().background(RemoteBody.background)) {
        // 本体が明るいグレーなので、見出しと設定のボタンは黒にする
        CompositionLocalProvider(LocalContentColor provides Color.Black) {
            ScreenHeader(AppStrings.tabRemote) {
                HeaderIconButton(Icons.Filled.Settings, AppStrings.settingsTitle, modifier = Modifier.testTag("settings.open")) {
                    sendAction(AppAction.showSettings())
                }
            }
        }
        Column(
            Modifier.verticalScroll(
                rememberScrollState(),
            ).padding(DesignDimensions.spacingOuter).padding(bottom = LocalMiniPlayerInset.current),
            verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingGroup),
        ) {
            // 電源は誤って押さないよう左端に離し、入力切替・消音と並べる
            Row(horizontalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem), modifier = Modifier.fillMaxWidth()) {
                KeyButton(Keys.power, press, Modifier.width(88.dp), isFilled = true)
                Spacer(Modifier.weight(1f))
                KeyButton(Keys.input, press, Modifier.width(88.dp))
                KeyButton(Keys.mute, press, Modifier.width(88.dp))
            }

            // 地デジ・BS・CS と 1〜12。テレビのリモコンと同じ 3 列。いま見ている放送の種類は緑にする
            Column(verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem)) {
                KeyRow {
                    listOf(Keys.terrestrial to "terrestrial", Keys.bs to "bs", Keys.cs to "cs").forEach { (key, name) ->
                        KeyButton(key, press, Modifier.weight(1f), size = ButtonSize.Compact, isSelected = band == name)
                    }
                }
                Keys.numbers.chunked(3).forEach { row ->
                    KeyRow { row.forEach { KeyButton(it, press, Modifier.weight(1f), isNumber = true) } }
                }
            }

            NavigationBand(press)

            RemoteSection(AppStrings.remotePlayback) {
                KeyRow {
                    KeyButton(Keys.previousChapter, press, Modifier.weight(1f), size = ButtonSize.Primary)
                    KeyButton(Keys.skipBackward, press, Modifier.weight(1f), size = ButtonSize.Primary)
                    KeyButton(
                        if (nowPlaying?.isAdvancing ==
                            true
                        ) {
                            Keys.pause
                        } else {
                            Keys.play
                        },
                        press,
                        Modifier.weight(1f),
                        size = ButtonSize.Primary,
                    )
                    KeyButton(Keys.skipForward, press, Modifier.weight(1f), size = ButtonSize.Primary)
                    KeyButton(Keys.nextChapter, press, Modifier.weight(1f), size = ButtonSize.Primary)
                }
                KeyRow {
                    KeyButton(Keys.rewind, press, Modifier.weight(1f))
                    KeyButton(Keys.stop, press, Modifier.weight(1f))
                    KeyButton(Keys.fastForward, press, Modifier.weight(1f))
                    KeyButton(Keys.record, press, Modifier.weight(1f), isDestructive = true)
                }
                KeyRow {
                    listOf(Keys.recordedList, Keys.timeShift, Keys.jumpToStart).forEach {
                        KeyButton(it, press, Modifier.weight(1f), size = ButtonSize.Compact)
                    }
                }
            }

            // まれに使うキーは畳んでおく
            Column(verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem)) {
                Row(
                    Modifier.fillMaxWidth().clickable { isShowingMore = !isShowingMore }.padding(horizontal = 4.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        AppStrings.remoteMore,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = RemoteBody.sectionText,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(
                        Icons.Filled.KeyboardArrowDown,
                        contentDescription = null,
                        tint = RemoteBody.sectionText,
                        modifier = Modifier.rotate(if (isShowingMore) 180f else 0f),
                    )
                }
                AnimatedVisibility(isShowingMore) {
                    Column(verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem)) {
                        Keys.others.chunked(3).forEach { row ->
                            KeyRow { row.forEach { KeyButton(it, press, Modifier.weight(1f), size = ButtonSize.Compact) } }
                        }
                    }
                }
            }
        }
    }
}

/** 十字キー・戻るなど・色ボタン。実物のリモコンと同じく、ここだけ端から端まで黒い帯にする */
@Composable
private fun NavigationBand(press: (RegzaKey) -> Unit) {
    Column(
        Modifier
            // 外側の余白を打ち消して、画面の端まで帯を伸ばす
            .layoutFullWidth(DesignDimensions.spacingOuter)
            .background(RemoteBody.panel)
            .padding(vertical = DesignDimensions.spacingGroup, horizontal = DesignDimensions.spacingOuter),
        verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem),
    ) {
        // 音量・十字キー・チャンネル
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem)) {
            Rocker(AppStrings.remoteVolume, Keys.volumeUp, "+", Keys.volumeDown, "−", press, Modifier.width(64.dp))
            Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { DirectionPad(press, 196.dp) }
            Rocker("CH", Keys.channelUp, null, Keys.channelDown, null, press, Modifier.width(64.dp))
        }
        KeyRow {
            listOf(
                Keys.back to null,
                Keys.guide to AppStrings.remoteTvGuide,
                Keys.programInfo to AppStrings.programDescription,
                Keys.exit to null,
            ).forEach { (key, title) ->
                KeyButton(key, press, Modifier.weight(1f), title = title, tone = KeyTone.Black)
            }
        }
        KeyRow {
            ColorKey(Keys.blue, DesignColors.remoteKeyBlue, press)
            ColorKey(Keys.red, DesignColors.remoteKeyRed, press)
            ColorKey(Keys.green, DesignColors.remoteKeyGreen, press)
            ColorKey(Keys.yellow, DesignColors.remoteKeyYellow, press)
        }
    }
}

/** 外側の余白 (padding) の中に置いても、その分だけ左右に広げて画面の端まで描く */
private fun Modifier.layoutFullWidth(outer: Dp): Modifier = layout { measurable, constraints ->
    val extra = outer.roundToPx() * 2
    val placeable = measurable.measure(constraints.copy(minWidth = constraints.maxWidth + extra, maxWidth = constraints.maxWidth + extra))
    layout(constraints.maxWidth, placeable.height) { placeable.place(-outer.roundToPx(), 0) }
}

/** 見出し付きのまとまり */
@Composable
private fun RemoteSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem)) {
        Text(
            title,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = RemoteBody.sectionText,
            modifier = Modifier.padding(start = 4.dp),
        )
        content()
    }
}

@Composable
private fun KeyRow(content: @Composable RowScope.() -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(DesignDimensions.spacingItem), modifier = Modifier.fillMaxWidth(), content = content)
}

private enum class ButtonSize(val height: Dp) {
    Primary(
        DesignDimensions.buttonPrimaryHeight,
    ),
    Regular(DesignDimensions.buttonRegularHeight),
    Compact(DesignDimensions.buttonCompactHeight),
}

/** ボタンが置かれている場所。グレーの部分はグレーのボタンに黒い文字、黒い帯の部分は黒いボタンに白い文字 */
private enum class KeyTone { Gray, Black }

/**
 * キーを 1 つ送るボタン (iOS 版の KeyButton と RemoteButtonStyle)。
 * 色は選択中 (緑) と電源・録画 (赤) だけに使う。文字は iOS 版と同じ RegzaKey.label
 */
@Composable
private fun KeyButton(
    key: RegzaKey,
    press: (RegzaKey) -> Unit,
    modifier: Modifier = Modifier,
    title: String? = null,
    size: ButtonSize = ButtonSize.Regular,
    tone: KeyTone = KeyTone.Gray,
    isDestructive: Boolean = false,
    isFilled: Boolean = false,
    isSelected: Boolean = false,
    isNumber: Boolean = false,
) {
    val label = remember(key.rawValue, title) { title ?: key.label }
    val background = when {
        isFilled -> RemoteBody.power
        isSelected -> AppTheme.accent
        tone == KeyTone.Gray -> RemoteBody.grayKey
        else -> RemoteBody.key
    }
    val foreground = when {
        isFilled || isSelected -> Color.White
        tone == KeyTone.Gray -> if (isDestructive) DesignColors.remoteDestructiveOnGray else Color.Black
        else -> if (isDestructive) DesignColors.remoteDestructiveOnBlack else Color.White
    }
    val style = when {
        isNumber -> MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black)

        // 地デジ・BS・CS も数字と同じ太さにするが、数字が主役になるよう大きさはそのまま
        isBandKey(key) -> MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Black)

        size == ButtonSize.Compact -> MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold)

        else -> MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold)
    }
    PressableKey(
        onClick = { press(key) },
        shape = RoundedCornerShape(DesignDimensions.shapeCornerRadius),
        color = background,
        modifier = modifier.heightIn(min = size.height),
    ) {
        // 入りきらない名前は、iOS 版と同じく 1 行のまま 6 割まで小さくする
        BasicText(
            label,
            style = style.copy(color = foreground, textAlign = TextAlign.Center),
            maxLines = 1,
            autoSize = TextAutoSize.StepBased(minFontSize = style.fontSize * 0.6f, maxFontSize = style.fontSize),
            modifier = Modifier.padding(horizontal = DesignDimensions.remoteControlKeyInset),
        )
    }
}

private fun isBandKey(key: RegzaKey) = key.rawValue in setOf(Keys.terrestrial.rawValue, Keys.bs.rawValue, Keys.cs.rawValue)

/** 物のボタンらしく、押すと少し縮んで明るくなる面 */
@Composable
private fun PressableKey(onClick: () -> Unit, shape: Shape, color: Color, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val isPressed by interaction.collectIsPressedAsState()
    Box(
        modifier
            .scale(if (isPressed) 0.95f else 1f)
            .background(color, shape)
            .background(if (isPressed) Color.White.copy(alpha = 0.08f) else Color.Transparent, shape)
            // ボタンの上側のごく薄い光沢と縁
            .background(verticalGradient(DesignColors.remoteHighlight, Color.Transparent), shape)
            .border(BorderStroke(DesignDimensions.remoteControlBorderWidth, RemoteBody.edge), shape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** 青・赤・緑・黄のカラーボタン。テレビのリモコンと同じく細長い色の帯にする */
@Composable
private fun RowScope.ColorKey(key: RegzaKey, color: Color, press: (RegzaKey) -> Unit) {
    PressableKey(
        onClick = { press(key) },
        shape = RoundedCornerShape(DesignDimensions.shapeCornerRadius),
        color = RemoteBody.key,
        modifier = Modifier.weight(1f).height(DesignDimensions.buttonCompactHeight),
    ) {
        Box(
            Modifier.fillMaxWidth().padding(
                horizontal = DesignDimensions.remoteControlColorKeyInset,
            ).height(DesignDimensions.remoteControlColorKeyHeight).background(color, CircleShape),
        )
    }
}

/** 音量・チャンネルの縦長ボタン */
@Composable
private fun Rocker(
    title: String,
    up: RegzaKey,
    upText: String?,
    down: RegzaKey,
    downText: String?,
    press: (RegzaKey) -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(50)
    Column(
        modifier
            .background(RemoteBody.key, shape)
            .background(verticalGradient(DesignColors.remoteHighlight, Color.Transparent), shape)
            .border(DesignDimensions.remoteControlBorderWidth, RemoteBody.edge, shape),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        RockerHalf(up, upText, Icons.Filled.KeyboardArrowUp, press)
        Text(title, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.6f))
        RockerHalf(down, downText, Icons.Filled.KeyboardArrowDown, press)
    }
}

@Composable
private fun RockerHalf(key: RegzaKey, text: String?, icon: ImageVector, press: (RegzaKey) -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(DesignDimensions.remoteControlRockerHeight).clickable { press(key) },
        contentAlignment = Alignment.Center,
    ) {
        if (text != null) {
            Text(
                text,
                style = TextStyle(fontWeight = FontWeight.SemiBold),
                fontSize = MaterialTheme.typography.headlineSmall.fontSize,
                color = Color.White,
            )
        } else {
            Icon(icon, contentDescription = key.label, tint = Color.White, modifier = Modifier.size(32.dp))
        }
    }
}

/** 十字キーと決定。実物のリモコンと同じく、真ん中だけ銀色の一段浮いたボタンにする */
@Composable
private fun DirectionPad(press: (RegzaKey) -> Unit, diameter: Dp) {
    Box(
        Modifier.size(
            diameter,
        ).background(RemoteBody.ring, CircleShape).border(DesignDimensions.remoteControlBorderWidth, RemoteBody.edge, CircleShape),
    ) {
        val arrow = diameter * 0.3f
        Arrow(Keys.up, Icons.Filled.KeyboardArrowUp, press, Modifier.align(Alignment.TopCenter).size(arrow))
        Arrow(Keys.down, Icons.Filled.KeyboardArrowDown, press, Modifier.align(Alignment.BottomCenter).size(arrow))
        Arrow(Keys.left, Icons.Filled.KeyboardArrowLeft, press, Modifier.align(Alignment.CenterStart).size(arrow))
        Arrow(Keys.right, Icons.Filled.KeyboardArrowRight, press, Modifier.align(Alignment.CenterEnd).size(arrow))
        Box(
            Modifier
                .align(Alignment.Center)
                .size(diameter * 0.38f)
                .shadow(3.dp, CircleShape)
                .background(RemoteBody.center, CircleShape)
                .border(DesignDimensions.remoteControlBorderWidth, Color.White.copy(alpha = 0.25f), CircleShape)
                .clickable { press(Keys.enter) },
            contentAlignment = Alignment.Center,
        ) {
            Text(
                AppStrings.remoteEnter,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.Black.copy(alpha = 0.8f),
            )
        }
    }
}

@Composable
private fun Arrow(key: RegzaKey, icon: ImageVector, press: (RegzaKey) -> Unit, modifier: Modifier) {
    Box(modifier.clickable { press(key) }, contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = key.label, tint = Color.White, modifier = Modifier.size(32.dp))
    }
}

/** 画面で使うキー。RegzaKey は Swift の値なので、描き直すたびに作らず、ここで 1 度だけ作る */
private object Keys {
    val power = RegzaKey.power()
    val input = RegzaKey.input()
    val mute = RegzaKey.mute()
    val terrestrial = RegzaKey.terrestrial()
    val bs = RegzaKey.bs()
    val cs = RegzaKey.cs()
    val numbers = listOf(
        RegzaKey.num1(), RegzaKey.num2(), RegzaKey.num3(), RegzaKey.num4(), RegzaKey.num5(), RegzaKey.num6(),
        RegzaKey.num7(), RegzaKey.num8(), RegzaKey.num9(), RegzaKey.num10(), RegzaKey.num11(), RegzaKey.num12(),
    )
    val volumeUp = RegzaKey.volumeUp()
    val volumeDown = RegzaKey.volumeDown()
    val channelUp = RegzaKey.channelUp()
    val channelDown = RegzaKey.channelDown()
    val up = RegzaKey.up()
    val down = RegzaKey.down()
    val left = RegzaKey.left()
    val right = RegzaKey.right()
    val enter = RegzaKey.enter()
    val back = RegzaKey.back()
    val guide = RegzaKey.guide()
    val programInfo = RegzaKey.programInfo()
    val exit = RegzaKey.exit()
    val blue = RegzaKey.blue()
    val red = RegzaKey.red()
    val green = RegzaKey.green()
    val yellow = RegzaKey.yellow()
    val previousChapter = RegzaKey.previousChapter()
    val skipBackward = RegzaKey.skipBackward()
    val play = RegzaKey.play()
    val pause = RegzaKey.pause()
    val skipForward = RegzaKey.skipForward()
    val nextChapter = RegzaKey.nextChapter()
    val rewind = RegzaKey.rewind()
    val stop = RegzaKey.stop()
    val fastForward = RegzaKey.fastForward()
    val record = RegzaKey.record()
    val recordedList = RegzaKey.recordedList()
    val timeShift = RegzaKey.timeShift()
    val jumpToStart = RegzaKey.jumpToStart()

    /** 「その他の操作」に畳んでおくキー (iOS 版と同じ並び) */
    val others = listOf(
        RegzaKey.display(), RegzaKey.audio(), RegzaKey.subtitle(), RegzaKey.dData(), RegzaKey.miniGuide(), RegzaKey.channelNumber(),
        RegzaKey.radioData(), RegzaKey.programSearch(), RegzaKey.regzaMenu(), RegzaKey.settings(), RegzaKey.quick(), RegzaKey.screenSize(),
        RegzaKey.multiScreen(), RegzaKey.broadband(), RegzaKey.newsNow(), RegzaKey.pageUp(), RegzaKey.pageDown(), RegzaKey.threeD(),
    )
}

/** ミニプレーヤーの右端のボタンに使うキー: 録画は再生/一時停止、放送は消音、待機中は電源 */
fun miniPlayerKey(kind: String, isAdvancing: Boolean): RegzaKey? = when (kind) {
    "recorded" -> if (isAdvancing) Keys.pause else Keys.play
    "broadcast" -> Keys.mute
    "standby" -> Keys.power
    else -> null
}

@Preview(name = "リモコン")
@Composable
private fun RemoteScreenPreview() = SamplePreview(setUp = { it(RemoteAction.refresh()) }) { app, send ->
    rememberState(app) { app.remoteStates() }?.let { RemoteScreen(it, send) }
}
