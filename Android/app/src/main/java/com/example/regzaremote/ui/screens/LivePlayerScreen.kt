package com.example.regzaremote.ui.screens

import android.app.Activity
import android.content.res.Configuration
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.livePlayerStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.ChannelItem
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.LivePlayerAction
import com.example.regzaremote.core.LivePlayerPhase
import com.example.regzaremote.core.LivePlayerState
import com.example.regzaremote.core.RegzaAndroidBridge
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.Design
import com.example.regzaremote.ui.components.HeaderIconButton
import com.example.regzaremote.ui.components.Note
import com.example.regzaremote.ui.components.ProminentButton
import com.example.regzaremote.ui.components.RowDivider
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.preview.SAMPLE_CHANNEL
import com.example.regzaremote.ui.preview.SamplePreview
import kotlinx.coroutines.delay

/**
 * EPGStation のライブ配信をアプリで見る画面 (state と操作は LivePlayerViewModel の LivePlayerState・LivePlayerAction)。
 * 縦向きでは映像の下に今の番組の情報と局の一覧を出し、局を押すとその局の配信に切り替える。横向きでは映像だけを出す。
 * 閉じたり局を切り替えたりしたら、前の配信を止めてチューナーを空ける (LivePlayerViewModel)
 */
@Composable
fun LivePlayerScreen(player: LivePlayerState, send: Send) {
    // 画面を出したら、局名と番組を読み、配信を頼む
    LaunchedEffect(Unit) {
        send(LivePlayerAction.appear())
        send(LivePlayerAction.start())
    }
    BackHandler { send(AppAction.closePlayer()) }
    // 画面が消えたりほかのアプリに移ったりしたら、閉じて配信を止める。裏で見ていると知らせ続けると、
    // 見ていないのにチューナーを使い続けてしまう (Android ではピクチャインピクチャや裏での再生をしない)
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) { send(AppAction.closePlayer()) }
    val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
    FullScreenWhile(isLandscape)

    Box(Modifier.fillMaxSize().background(AppTheme.background)) {
        if (isLandscape) {
            Video(player, send, Modifier.fillMaxSize())
        } else {
            Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                // 閉じるだけの画面なので、左上の × で閉じる (映像の上には重ねない)
                ScreenHeader(
                    "ライブ視聴",
                    leading = { HeaderIconButton(Icons.Filled.Close, "閉じる") { send(AppAction.closePlayer()) } },
                )
                Video(player, send, Modifier.fillMaxWidth().aspectRatio(16f / 9f))
                Column(
                    Modifier.verticalScroll(rememberScrollState()).padding(vertical = Design.outer),
                    verticalArrangement = Arrangement.spacedBy(Design.group),
                ) {
                    ProgramInfo(player)
                    ChannelPicker(player, send)
                }
            }
        }
    }
}

/** 横向きの間は、ステータスバーとナビゲーションバーを隠して映像だけにする (端から引くと一時的に出る) */
@Composable
private fun FullScreenWhile(isFullScreen: Boolean) {
    val activity = LocalContext.current as? Activity ?: return
    DisposableEffect(isFullScreen) {
        val controller = WindowCompat.getInsetsController(activity.window, activity.window.decorView)
        if (isFullScreen) {
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(WindowInsetsCompat.Type.systemBars())
        }
        onDispose { controller.show(WindowInsetsCompat.Type.systemBars()) }
    }
}

/** 映像の場所。準備中・再生・失敗を出し分ける */
@Composable
private fun Video(player: LivePlayerState, send: Send, modifier: Modifier) {
    Box(modifier.background(Color.Black), contentAlignment = Alignment.Center) {
        val phase = player.phase
        when (phase.discriminator) {
            LivePlayerPhase.Discriminator.READY -> HlsPlayer(RegzaAndroidBridge.regzaURLString(phase.asReady.get().url))

            LivePlayerPhase.Discriminator.FAILED -> Column(
                Modifier.padding(Design.outer).verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                val failed = phase.asFailed.get()
                Text(
                    failed.message,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center,
                )
                if (failed.canRetry) {
                    ProminentButton("準備できていない配信を止めて、もう一度試す") { send(LivePlayerAction.retryAfterStoppingStalled()) }
                }
            }

            LivePlayerPhase.Discriminator.PREPARING -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CircularProgressIndicator(color = Color.White)
                Text(
                    player.preparingMessage,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.7f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = Design.outer),
                )
            }
        }
    }
}

/**
 * HLS の配信を ExoPlayer で再生する。URL が変わったら (局を切り替えたら) 再生し直す。
 * Android 標準の操作部品は、この配信を録画のように扱って配信を始めてからの時間とシークバーを出すので使わず、
 * iOS と同じく「ライブ」の印と再生・一時停止だけを出す (映像を押すと出て、しばらくすると消える)
 */
@Composable
private fun HlsPlayer(url: String) {
    val context = LocalContext.current
    val exoPlayer = remember { ExoPlayer.Builder(context).build() }
    var isPlaying by remember { mutableStateOf(false) }
    DisposableEffect(Unit) {
        val listener = object : Player.Listener {
            override fun onIsPlayingChanged(playing: Boolean) {
                isPlaying = playing
            }
        }
        exoPlayer.addListener(listener)
        onDispose {
            exoPlayer.removeListener(listener)
            exoPlayer.release()
        }
    }
    LaunchedEffect(url) {
        // EPGStation の URL は .m3u8 で終わるとは限らないので、HLS だと伝える
        exoPlayer.setMediaItem(MediaItem.Builder().setUri(url).setMimeType(MimeTypes.APPLICATION_M3U8).build())
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    var isShowingControls by remember { mutableStateOf(true) }
    // 再生している間は、操作を出してからしばらくしたら消す
    LaunchedEffect(isShowingControls, isPlaying) {
        if (isShowingControls && isPlaying) {
            delay(3000)
            isShowingControls = false
        }
    }
    Box(
        Modifier
            .fillMaxSize()
            .clickable(interactionSource = null, indication = null) { isShowingControls = !isShowingControls },
    ) {
        AndroidView(
            factory = {
                PlayerView(it).apply {
                    player = exoPlayer
                    useController = false
                }
            },
            modifier = Modifier.fillMaxSize(),
        )
        AnimatedVisibility(isShowingControls, enter = fadeIn(), exit = fadeOut(), modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f))) {
                LiveBadge(Modifier.align(Alignment.TopStart).padding(12.dp))
                PlayPauseButton(isPlaying, Modifier.align(Alignment.Center)) {
                    if (isPlaying) exoPlayer.pause() else exoPlayer.play()
                    isShowingControls = true
                }
            }
        }
    }
}

/** 放送をそのまま見ている印 */
@Composable
private fun LiveBadge(modifier: Modifier) {
    Row(
        modifier.background(Color.Black.copy(alpha = 0.5f), CircleShape).padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Box(Modifier.size(7.dp).background(AppTheme.red, CircleShape))
        Text("ライブ", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
    }
}

/** 再生と一時停止を入れ替えるボタン (一時停止の印は Material のアイコンにないので描く) */
@Composable
private fun PlayPauseButton(isPlaying: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(64.dp).background(Color.Black.copy(alpha = 0.5f), CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (isPlaying) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(2) { Box(Modifier.size(width = 6.dp, height = 22.dp).background(Color.White, RoundedCornerShape(2.dp))) }
            }
        } else {
            Icon(Icons.Filled.PlayArrow, contentDescription = "再生", tint = Color.White, modifier = Modifier.size(40.dp))
        }
    }
}

/** 見ている局の今の番組 (Mirakurun の番組表から) */
@Composable
private fun ProgramInfo(player: LivePlayerState) {
    val program = player.program.orElse(null)
    Column(Modifier.padding(horizontal = Design.outer), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            player.channelName + if (program == null) "" else " · 放送中",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppTheme.accent,
        )
        Text(program?.name ?: player.channelName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        if (program != null) {
            Note(program.timeText + (program.genreName.orElse(null)?.let { " · $it" } ?: ""))
            val start = program.start.timeIntervalSince1970
            val end = program.end.timeIntervalSince1970
            val now = System.currentTimeMillis() / 1000.0
            LinearProgressIndicator(
                progress = { ((now - start) / (end - start)).toFloat().coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth(),
                color = AppTheme.accent,
                trackColor = AppTheme.fill,
                drawStopIndicator = {},
            )
            if (program.description.isNotEmpty()) {
                Text(
                    program.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** 見られる局の一覧。押すとその局に切り替える */
@Composable
private fun ChannelPicker(player: LivePlayerState, send: Send) {
    Column {
        BandPicker(player.bands, player.band.orElse(null), send)
        player.channels.forEach { row ->
            ChannelRow(row) { send(LivePlayerAction.switchChannel(row.code)) }
            RowDivider()
        }
    }
}

@Composable
private fun ChannelRow(row: ChannelItem, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = Design.outer, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(row.numberText, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(Modifier.weight(1f)) {
            Text(row.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
            row.programName.orElse(null)?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        if (row.isNowPlaying) Icon(Icons.Filled.PlayArrow, contentDescription = "再生中", tint = AppTheme.accent)
    }
}

@Preview(name = "ライブ視聴")
@Composable
private fun LivePlayerScreenPreview() = SamplePreview(setUp = {
    it(ChannelListAction.appear())
    it(AppAction.play(SAMPLE_CHANNEL))
    it(LivePlayerAction.appear())
    it(LivePlayerAction.start())
}) { app, send ->
    rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, send) }
}
