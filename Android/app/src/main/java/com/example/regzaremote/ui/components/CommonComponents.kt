package com.example.regzaremote.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.Design

/**
 * タブの画面の下に重ねて浮かせているミニプレーヤーの高さ。一覧の最後がミニプレーヤーに隠れないよう、
 * スクロールする画面はこの分だけ下に余白を足す (タブの中でない画面では 0)
 */
val LocalMiniPlayerInset = compositionLocalOf { 0.dp }

/** 補足の説明 */
@Composable
fun Note(text: String, modifier: Modifier = Modifier) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = modifier)
}

/**
 * 画面の上の見出し。iOS 版と同じく、題名は真ん中に小さく出し、右に画面ごとのボタンを置く。
 * タブの中で開いた画面なら、左に戻るボタンも出す (leading で、戻るの代わりに閉じるボタンなども置ける)
 */
@Composable
fun ScreenHeader(
    title: String,
    onBack: (() -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp)) {
        Box(Modifier.align(Alignment.CenterStart)) {
            when {
                onBack != null -> IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る") }
                leading != null -> leading()
            }
        }
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.align(Alignment.Center).padding(horizontal = 56.dp),
        )
        Row(Modifier.align(Alignment.CenterEnd), verticalAlignment = Alignment.CenterVertically, content = actions)
    }
}

/**
 * 一覧の代わりに出す、何もないときや取得できなかったときの案内 (iOS の ContentUnavailableView)。
 * 画面の真ん中に、題名・説明・ボタンを縦に並べる
 */
@Composable
fun EmptyState(title: String, message: String? = null, action: (@Composable () -> Unit)? = null) {
    Box(Modifier.fillMaxSize().padding(horizontal = 32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            message?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            action?.let { Box(Modifier.padding(top = 8.dp)) { it() } }
        }
    }
}

/** 塗りつぶしの大きなボタン (案内の「設定を開く」など) */
@Composable
fun ProminentButton(text: String, onClick: () -> Unit) {
    Button(onClick = onClick, colors = ButtonDefaults.buttonColors(containerColor = AppTheme.accent, contentColor = Color.White)) {
        Text(text, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * 見出しと補足の付いた、角の丸いまとまり (iOS の List や Form の Section)。
 * 行の間には線を引く
 */
@Composable
fun FormSection(
    header: String? = null,
    footer: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        header?.let { SectionHeader(it) }
        Column(Modifier.fillMaxWidth().background(AppTheme.surface, RoundedCornerShape(Design.cornerRadius)), content = content)
        footer?.let { Note(it, Modifier.padding(horizontal = Design.outer)) }
    }
}

/** まとまりの見出し */
@Composable
fun SectionHeader(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(horizontal = Design.outer),
    )
}

/** まとまりの中の行の間の線。左端は行の文字にそろえる */
@Composable
fun RowDivider() {
    HorizontalDivider(Modifier.padding(start = Design.outer), thickness = 0.5.dp, color = AppTheme.separator)
}

/**
 * 長い一覧 (LazyColumn) で、行ごとにまとまりの形を作る。最初と最後の行だけ角を丸める
 */
fun sectionRowShape(index: Int, count: Int): Shape {
    val radius = Design.cornerRadius
    val top = if (index == 0) radius else 0.dp
    val bottom = if (index == count - 1) radius else 0.dp
    return RoundedCornerShape(topStart = top, topEnd = top, bottomStart = bottom, bottomEnd = bottom)
}

/** 録画予約した番組に付ける印 (iOS 版の ReservedBadge と同じく、赤い地に白い文字) */
@Composable
fun ReservedBadge(compact: Boolean = false) {
    Row(
        Modifier.background(AppTheme.red, CircleShape).padding(horizontal = if (compact) 4.dp else 6.dp, vertical = 1.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        RecordIcon(Modifier.size(9.dp), color = Color.White)
        Text(
            if (compact) "予約" else "録画予約済み",
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = Color.White,
        )
    }
}

/** 録画の印 (二重の丸)。Material のアイコンにないので描く */
@Composable
fun RecordIcon(modifier: Modifier = Modifier, color: Color = AppTheme.red) {
    Canvas(modifier) {
        drawCircle(color, radius = size.minDimension / 2, style = androidx.compose.ui.graphics.drawscope.Stroke(size.minDimension * 0.12f))
        drawCircle(color, radius = size.minDimension * 0.3f)
    }
}

/** 上から下へ色の変わる面 (リモコンの本体など) */
fun verticalGradient(top: Color, bottom: Color) = Brush.verticalGradient(listOf(top, bottom))

/** 画面の真ん中に出す読み込み中の印 */
@Composable
fun Loading() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        androidx.compose.material3.CircularProgressIndicator()
    }
}

/** 見出しに置くアイコンのボタン。保存などの確定のボタンは強調色にする */
@Composable
fun HeaderIconButton(
    icon: ImageVector,
    description: String,
    enabled: Boolean = true,
    tint: Color? = null,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    IconButton(onClick = onClick, enabled = enabled, modifier = modifier) {
        if (tint != null &&
            enabled
        ) {
            Icon(icon, contentDescription = description, tint = tint)
        } else {
            Icon(icon, contentDescription = description)
        }
    }
}
