package com.example.regzaremote

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.ServerSetupAction
import com.example.regzaremote.core.ServerSetupServer
import com.example.regzaremote.core.ServerSetupServerState
import com.example.regzaremote.core.SettingsAction
import com.example.regzaremote.core.SettingsPage
import com.example.regzaremote.core.SettingsState
import com.example.regzaremote.core.TVSetupAction

/**
 * 設定 (state と操作は SettingsViewModel の SettingsState・SettingsAction)。
 * 最初の画面にテレビと録画サーバーの状態を並べ、押すとそれぞれの設定の画面を開く
 * (テレビが未設定なら、SettingsViewModel がテレビの設定の画面から開く)
 */
@Composable
fun SettingsScreen(setup: SettingsState, send: Send) {
    when (setup.path.lastOrNull()?.rawValue) {
        "tv" -> TVSettingsPage(setup, send)
        "guide" -> ServerSettingsPage(guidePage, setup.servers.guide, setup, send)
        "stream" -> ServerSettingsPage(streamPage, setup.servers.stream, setup, send)
        else -> SettingsTopPage(setup, send)
    }
}

/** テレビの登録の操作を送る */
private fun tv(action: TVSetupAction) = SettingsAction.tv(action)

@Composable
private fun SettingsTopPage(setup: SettingsState, send: Send) {
    // 登録済みのテレビがあれば、戻るボタンでも閉じる
    BackHandler(enabled = setup.isCanClose) { send(SettingsAction.close()) }
    val servers = setup.servers
    SettingsFrame(
        header = {
            // キャンセルは左上の ×、保存は右上の ✓ (iOS 版と同じ)
            ScreenHeader(
                "設定",
                leading = if (setup.isCanClose) {
                    (
                        {
                            HeaderIconButton(Icons.Filled.Close, "閉じる") { send(SettingsAction.close()) }
                        }
                        )
                } else {
                    null
                },
            ) {
                HeaderIconButton(Icons.Filled.Check, "保存", enabled = setup.isCanSave, tint = AppTheme.accent) {
                    send(SettingsAction.save())
                }
            }
        },
    ) {
        FormSection("テレビ") {
            val status = setup.tv.status
            NavigationRow("REGZA", status.text, valueColor = if (status.isNeedsAttention) AppTheme.orange else null) {
                send(SettingsAction.openPage(SettingsPage.tv()))
            }
        }
        FormSection(
            "録画サーバーとの連携",
            footer = "Mirakurun や EPGStation を使っている場合だけ設定してください。設定すると、番組名・番組表・番組表からの録画予約や、" +
                "アプリでのライブ視聴が使えます。\nライブ視聴（EPGStation）は、番組表（Mirakurun）を設定すると設定できます。",
        ) {
            NavigationRow("番組表（Mirakurun）", servers.guide.status) { send(SettingsAction.openPage(SettingsPage.guide())) }
            RowDivider()
            // EPGStation は Mirakurun から放送を受け取るので、Mirakurun を設定してから設定できるようにする
            NavigationRow(
                "ライブ視聴（EPGStation）",
                if (servers.isHasGuideDraft) servers.stream.status else "先に番組表を設定",
                enabled = servers.isHasGuideDraft,
            ) { send(SettingsAction.openPage(SettingsPage.stream())) }
        }
    }
}

/** テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト */
@Composable
private fun TVSettingsPage(setup: SettingsState, send: Send) {
    val state = setup.tv
    BackHandler { send(SettingsAction.back()) }
    // 未設定なら開いたときに探し始める
    LaunchedEffect(Unit) { send(tv(TVSetupAction.appear())) }
    val isBusy = state.isPairing || state.isWaitingForPIN

    SettingsFrame(header = { ScreenHeader("REGZA", onBack = { send(SettingsAction.back()) }) }) {
        FormSection(
            "テレビ",
            footer = "スマートフォンとテレビを同じ Wi-Fi につないでください。見つからないときは、テレビの「設定」→「ネットワーク」で IP アドレスを確認して入力してください。",
        ) {
            FormTextField(
                state.host,
                { send(tv(TVSetupAction.setHost(it))) },
                "IPアドレス (例: 192.168.0.10)",
                enabled = !state.isWaitingForPIN,
                keyboardType = KeyboardType.Uri,
            )
            state.devices.forEach { device ->
                RowDivider()
                FormRow(onClick = if (isBusy) null else ({ send(tv(TVSetupAction.select(device.host))) })) {
                    Column(Modifier.weight(1f)) {
                        Text(device.name)
                        Note(device.host)
                    }
                    if (device.isSelected) Icon(Icons.Filled.Check, contentDescription = "選択中", tint = AppTheme.accent)
                }
            }
            RowDivider()
            ActionRow(
                if (state.isScanning) "テレビを探しています…" else "テレビを探す",
                isBusy = state.isScanning,
                enabled = !state.isScanning && !state.isWaitingForPIN,
            ) { send(tv(TVSetupAction.scan())) }
            state.scanMessage.orElse(null)?.let {
                RowDivider()
                MessageRow(it)
            }
        }

        FormSection(
            "PIN で登録",
            footer = if (state.isWaitingForPIN) {
                "テレビの画面に表示されている PIN を入力してください。"
            } else {
                "テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。"
            },
        ) {
            if (!state.isWaitingForPIN) {
                ActionRow(
                    if (state.isRegistered) "もう一度登録する" else "テレビに PIN を表示",
                    isBusy = state.isPairing,
                    enabled = state.isHasAddress && !state.isPairing,
                ) { send(tv(TVSetupAction.startPairing())) }
            } else {
                // テレビに PIN が出たら、すぐ打てるようにする
                val focus = remember { FocusRequester() }
                LaunchedEffect(Unit) { focus.requestFocus() }
                FormTextField(
                    state.pin,
                    { send(tv(TVSetupAction.setPIN(it))) },
                    "テレビに表示された PIN",
                    keyboardType = KeyboardType.NumberPassword,
                    modifier = Modifier.focusRequester(focus),
                )
                RowDivider()
                // PIN で登録できたら、SettingsViewModel が設定を閉じる
                ActionRow("登録", isBusy = state.isPairing, enabled = state.pin.isNotBlank() && !state.isPairing) {
                    send(tv(TVSetupAction.confirmPairing()))
                }
                RowDivider()
                ActionRow("やめる", enabled = !state.isPairing) { send(tv(TVSetupAction.cancelPairing())) }
            }
            state.pairingMessage.orElse(null)?.let {
                RowDivider()
                MessageRow(it)
            }
        }

        FormSection(footer = "PIN 登録に対応していない古い機種では、テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。") {
            FormRow(onClick = { send(tv(TVSetupAction.setShowingManualEntry(!state.isShowingManualEntry))) }) {
                Text("ユーザー名とパスワードを入力", Modifier.weight(1f))
                Icon(
                    Icons.Filled.KeyboardArrowDown,
                    contentDescription = null,
                    tint = AppTheme.accent,
                    modifier = Modifier.rotate(if (state.isShowingManualEntry) 180f else 0f),
                )
            }
            if (state.isShowingManualEntry) {
                RowDivider()
                FormTextField(state.user, { send(tv(TVSetupAction.setUser(it))) }, "ユーザー名")
                RowDivider()
                FormTextField(state.password, { send(tv(TVSetupAction.setPassword(it))) }, "パスワード", isPassword = true)
            }
        }

        FormSection {
            ActionRow("接続テスト", isBusy = state.isTesting, enabled = state.isHasAddress && !state.isTesting) {
                send(tv(TVSetupAction.test()))
            }
            state.testResult.orElse(null)?.let {
                RowDivider()
                MessageRow(it)
            }
        }
    }
}

/** 録画サーバー (Mirakurun・EPGStation) の設定の画面の文言 */
private class ServerPage(val server: () -> ServerSetupServer, val title: String, val header: String, val footer: String, val name: String)

/** 番組表 (Mirakurun) の設定 */
private val guidePage = ServerPage(
    server = { ServerSetupServer.guide() },
    title = "番組表（Mirakurun）",
    header = "番組表 (Mirakurun)",
    footer = "Mirakurun を動かしている場合に設定すると、放送中の番組名と番組表を表示します。使わない場合は空のままにしてください。",
    name = "Mirakurun",
)

/** ライブ視聴 (EPGStation) の設定 */
private val streamPage = ServerPage(
    server = { ServerSetupServer.stream() },
    title = "ライブ視聴（EPGStation）",
    header = "ライブ視聴 (EPGStation)",
    footer = "EPGStation を動かしている場合に設定すると、放送中の番組をスマートフォンで見られます。家の Wi-Fi の中だけで使えます。",
    name = "EPGStation",
)

/** 録画サーバーの設定の画面。保存済みなら、連携を解除するボタンも出す */
@Composable
private fun ServerSettingsPage(page: ServerPage, state: ServerSetupServerState, setup: SettingsState, send: Send) {
    fun server(action: (ServerSetupServer) -> ServerSetupAction) = SettingsAction.server(action(page.server()))
    BackHandler { send(SettingsAction.back()) }
    var isConfirmingUnlink by remember { mutableStateOf(false) }

    SettingsFrame(header = { ScreenHeader(page.title, onBack = { send(SettingsAction.back()) }) }) {
        FormSection(page.header, footer = page.footer) {
            FormTextField(
                state.host,
                { host -> send(server { ServerSetupAction.setHost(it, host) }) },
                "IPアドレス (例: 192.168.0.2)",
                keyboardType = KeyboardType.Uri,
            )
            if (!setup.servers.isValid) {
                MessageRow("ポートは 1〜65535 の数字で入れてください。", color = AppTheme.red)
            }
            state.hosts.forEach { host ->
                RowDivider()
                FormRow(onClick = { send(server { ServerSetupAction.setHost(it, host) }) }) {
                    Text(host, Modifier.weight(1f))
                    if (host == state.host) Icon(Icons.Filled.Check, contentDescription = "選択中", tint = AppTheme.accent)
                }
            }
            RowDivider()
            ActionRow(
                if (state.isScanning) "${page.name} を探しています…" else "${page.name} を探す",
                isBusy = state.isScanning,
                enabled = !state.isScanning,
            ) { send(server { ServerSetupAction.scan(it) }) }
            state.message.orElse(null)?.let {
                RowDivider()
                MessageRow(it)
            }
        }
        if (state.isLinked) {
            FormSection {
                ActionRow("連携を解除", color = AppTheme.red) { isConfirmingUnlink = true }
            }
        }
    }

    if (isConfirmingUnlink) {
        AlertDialog(
            onDismissRequest = { isConfirmingUnlink = false },
            title = { Text(state.unlinkTitle) },
            text = { Text(state.unlinkMessage) },
            confirmButton = {
                TextButton(onClick = {
                    isConfirmingUnlink = false
                    // すぐにアドレスを消して反映する (SettingsViewModel が設定の最初の画面に戻る)
                    send(server { ServerSetupAction.unlink(it) })
                }) { Text("連携を解除", color = AppTheme.red) }
            },
            dismissButton = { TextButton(onClick = { isConfirmingUnlink = false }) { Text("やめる") } },
        )
    }
}

/** 設定の画面の枠。見出しの下に、まとまりを縦に並べてスクロールする */
@Composable
private fun SettingsFrame(header: @Composable () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    // Android 15 からは画面の端まで描くので、タブの画面 (Scaffold) と同じく、ステータスバーと
    // ナビゲーションバー・キーボードの分を空ける
    Column(Modifier.fillMaxSize().safeDrawingPadding()) {
        header()
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = Design.outer).padding(bottom = Design.group),
            verticalArrangement = Arrangement.spacedBy(Design.group),
            content = content,
        )
    }
}

/** まとまりの中の 1 行 */
@Composable
private fun FormRow(onClick: (() -> Unit)? = null, content: @Composable RowScope.() -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = Design.outer, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

/** 別の画面を開く行。右に今の状態を出す */
@Composable
private fun NavigationRow(title: String, value: String, valueColor: Color? = null, enabled: Boolean = true, onClick: () -> Unit) {
    FormRow(onClick = if (enabled) onClick else null) {
        Text(title, Modifier.weight(1f), color = if (enabled) Color.Unspecified else MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, color = valueColor ?: MaterialTheme.colorScheme.onSurfaceVariant)
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** 押すと何かをする行 (強調色の文字)。動いている間は右に回る印を出す */
@Composable
private fun ActionRow(
    title: String,
    isBusy: Boolean = false,
    enabled: Boolean = true,
    color: Color = AppTheme.accent,
    onClick: () -> Unit,
) {
    FormRow(onClick = if (enabled) onClick else null) {
        Text(
            title,
            color = if (enabled) color else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.weight(1f),
        )
        if (isBusy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
    }
}

/** 結果や説明の行 */
@Composable
private fun MessageRow(text: String, color: Color? = null) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = color ?: MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = Design.outer, vertical = 10.dp),
    )
}

/**
 * まとまりの中の入力欄 (枠を付けず、行として並べる)。打った文字はこの画面ですぐに出し、Swift の ViewModel には操作として送る
 */
@Composable
private fun FormTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
) {
    val text = rememberSyncedText(value)
    TextField(
        value = text.value,
        onValueChange = { text.update(it, onValueChange) },
        placeholder = { Text(placeholder) },
        singleLine = true,
        enabled = enabled,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            disabledContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
        ),
        modifier = modifier.fillMaxWidth(),
    )
}

@Preview(name = "設定")
@Composable
private fun SettingsScreenPreview() = SamplePreview(setUp = { it(AppAction.showSettings()) }) { app, send ->
    rememberState(app) { app.settingsStates() }?.let { SettingsScreen(it, send) }
}
