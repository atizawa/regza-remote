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
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidSetup

/**
 * 設定 (iOS 版の SettingsView と同じ TVSetupViewModel・ServerSetupViewModel)。
 * 最初の画面にテレビと録画サーバーの状態を並べ、押すとそれぞれの設定の画面を開く
 * (テレビが未設定なら、AppViewModel がテレビの設定の画面から開く)
 */
@Composable
fun SettingsScreen(setup: RegzaAndroidSetup, send: Send) {
    // PIN で登録できたら (保存も済んでいる) 閉じる
    LaunchedEffect(setup.isHasRegistered) { if (setup.isHasRegistered) send(RegzaAndroidAction.closeSetup()) }
    when (setup.page) {
        "tv" -> TVSettingsPage(setup, send)
        "guide" -> GuideSettingsPage(setup, send)
        else -> SettingsTopPage(setup, send)
    }
}

@Composable
private fun SettingsTopPage(setup: RegzaAndroidSetup, send: Send) {
    // 登録済みのテレビがあれば、戻るボタンでも閉じる
    BackHandler(enabled = setup.isCanClose) { send(RegzaAndroidAction.closeSetup()) }
    SettingsPage(
        header = {
            // キャンセルは左上の ×、保存は右上の ✓ (iOS 版と同じ)
            ScreenHeader(
                "設定",
                leading = if (setup.isCanClose) ({ HeaderIconButton(Icons.Filled.Close, "閉じる") { send(RegzaAndroidAction.closeSetup()) } }) else null,
            ) {
                HeaderIconButton(Icons.Filled.Check, "保存", enabled = setup.isCanSave, tint = AppTheme.accent) { send(RegzaAndroidAction.save()) }
            }
        },
    ) {
        FormSection("テレビ") {
            NavigationRow("REGZA", setup.tvStatus, valueColor = if (setup.isTvNeedsAttention) AppTheme.orange else null) {
                send(RegzaAndroidAction.openSetupPage("tv"))
            }
        }
        FormSection(
            "録画サーバーとの連携",
            footer = "Mirakurun を使っている場合だけ設定してください。設定すると、番組名・番組表・番組表からの録画予約が使えます。",
        ) {
            NavigationRow("番組表（Mirakurun）", setup.guideStatus) { send(RegzaAndroidAction.openSetupPage("guide")) }
        }
    }
}

/** テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト */
@Composable
private fun TVSettingsPage(setup: RegzaAndroidSetup, send: Send) {
    BackHandler { send(RegzaAndroidAction.closeSetupPage()) }
    // 未設定なら開いたときに探し始める
    LaunchedEffect(Unit) { send(RegzaAndroidAction.setupAppear()) }
    val isBusy = setup.isPairing || setup.isWaitingForPIN

    SettingsPage(header = { ScreenHeader("REGZA", onBack = { send(RegzaAndroidAction.closeSetupPage()) }) }) {
        FormSection(
            "テレビ",
            footer = "スマートフォンとテレビを同じ Wi-Fi につないでください。見つからないときは、テレビの「設定」→「ネットワーク」で IP アドレスを確認して入力してください。",
        ) {
            FormTextField(
                setup.host, { send(RegzaAndroidAction.setHost(it)) }, "IPアドレス (例: 192.168.0.10)",
                enabled = !setup.isWaitingForPIN, keyboardType = KeyboardType.Uri,
            )
            setup.devices.forEach { device ->
                RowDivider()
                FormRow(onClick = if (isBusy) null else ({ send(RegzaAndroidAction.selectDevice(device.host)) })) {
                    Column(Modifier.weight(1f)) {
                        Text(device.name)
                        Note(device.host)
                    }
                    if (device.isSelected) Icon(Icons.Filled.Check, contentDescription = "選択中", tint = AppTheme.accent)
                }
            }
            RowDivider()
            ActionRow(
                if (setup.isScanning) "テレビを探しています…" else "テレビを探す", isBusy = setup.isScanning,
                enabled = !setup.isScanning && !setup.isWaitingForPIN,
            ) { send(RegzaAndroidAction.scan()) }
            setup.scanMessage.orElse(null)?.let { RowDivider(); MessageRow(it) }
        }

        FormSection(
            "PIN で登録",
            footer = if (setup.isWaitingForPIN) "テレビの画面に表示されている PIN を入力してください。"
            else "テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。",
        ) {
            if (!setup.isWaitingForPIN) {
                ActionRow(
                    if (setup.isRegistered) "もう一度登録する" else "テレビに PIN を表示", isBusy = setup.isPairing,
                    enabled = setup.host.isNotBlank() && !setup.isPairing,
                ) { send(RegzaAndroidAction.startPairing()) }
            } else {
                // テレビに PIN が出たら、すぐ打てるようにする
                val focus = remember { FocusRequester() }
                LaunchedEffect(Unit) { focus.requestFocus() }
                FormTextField(
                    setup.pin, { send(RegzaAndroidAction.setPIN(it)) }, "テレビに表示された PIN",
                    keyboardType = KeyboardType.NumberPassword, modifier = Modifier.focusRequester(focus),
                )
                RowDivider()
                ActionRow("登録", isBusy = setup.isPairing, enabled = setup.pin.isNotBlank() && !setup.isPairing) {
                    send(RegzaAndroidAction.confirmPairing())
                }
                RowDivider()
                ActionRow("やめる", enabled = !setup.isPairing) { send(RegzaAndroidAction.cancelPairing()) }
            }
            setup.pairingMessage.orElse(null)?.let { RowDivider(); MessageRow(it) }
        }

        FormSection(footer = "PIN 登録に対応していない古い機種では、テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。") {
            FormRow(onClick = { send(RegzaAndroidAction.setShowingManualEntry(!setup.isShowingManualEntry)) }) {
                Text("ユーザー名とパスワードを入力", Modifier.weight(1f))
                Icon(
                    Icons.Filled.KeyboardArrowDown, contentDescription = null, tint = AppTheme.accent,
                    modifier = Modifier.rotate(if (setup.isShowingManualEntry) 180f else 0f),
                )
            }
            if (setup.isShowingManualEntry) {
                RowDivider()
                FormTextField(setup.user, { send(RegzaAndroidAction.setUser(it)) }, "ユーザー名")
                RowDivider()
                FormTextField(setup.password, { send(RegzaAndroidAction.setPassword(it)) }, "パスワード", isPassword = true)
            }
        }

        FormSection {
            ActionRow("接続テスト", isBusy = setup.isTesting, enabled = setup.host.isNotBlank() && !setup.isTesting) {
                send(RegzaAndroidAction.test())
            }
            setup.testResult.orElse(null)?.let { RowDivider(); MessageRow(it) }
        }
    }
}

/** 番組表 (Mirakurun) の設定。保存済みなら、連携を解除するボタンも出す */
@Composable
private fun GuideSettingsPage(setup: RegzaAndroidSetup, send: Send) {
    BackHandler { send(RegzaAndroidAction.closeSetupPage()) }
    var isConfirmingUnlink by remember { mutableStateOf(false) }

    SettingsPage(header = { ScreenHeader("番組表（Mirakurun）", onBack = { send(RegzaAndroidAction.closeSetupPage()) }) }) {
        FormSection(
            "番組表 (Mirakurun)",
            footer = "Mirakurun を動かしている場合に設定すると、放送中の番組名と番組表を表示します。使わない場合は空のままにしてください。",
        ) {
            FormTextField(
                setup.guideHost, { send(RegzaAndroidAction.setGuideHost(it)) }, "IPアドレス (例: 192.168.0.2)",
                keyboardType = KeyboardType.Uri,
            )
            if (!setup.isGuideHostValid) {
                MessageRow("ポートは 1〜65535 の数字で入れてください。", color = AppTheme.red)
            }
            setup.guideHosts.forEach { host ->
                RowDivider()
                FormRow(onClick = { send(RegzaAndroidAction.setGuideHost(host)) }) {
                    Text(host, Modifier.weight(1f))
                    if (host == setup.guideHost) Icon(Icons.Filled.Check, contentDescription = "選択中", tint = AppTheme.accent)
                }
            }
            RowDivider()
            ActionRow(
                if (setup.isScanningGuide) "Mirakurun を探しています…" else "Mirakurun を探す", isBusy = setup.isScanningGuide,
                enabled = !setup.isScanningGuide,
            ) { send(RegzaAndroidAction.scanGuide()) }
            setup.guideMessage.orElse(null)?.let { RowDivider(); MessageRow(it) }
        }
        if (setup.isGuideLinked) {
            FormSection {
                ActionRow("連携を解除", color = AppTheme.red) { isConfirmingUnlink = true }
            }
        }
    }

    if (isConfirmingUnlink) {
        AlertDialog(
            onDismissRequest = { isConfirmingUnlink = false },
            title = { Text(setup.guideUnlinkTitle) },
            text = { Text(setup.guideUnlinkMessage) },
            confirmButton = {
                TextButton(onClick = {
                    isConfirmingUnlink = false
                    // すぐにアドレスを消して反映し、設定の最初の画面に戻る
                    send(RegzaAndroidAction.unlinkGuide())
                    send(RegzaAndroidAction.closeSetupPage())
                }) { Text("連携を解除", color = AppTheme.red) }
            },
            dismissButton = { TextButton(onClick = { isConfirmingUnlink = false }) { Text("やめる") } },
        )
    }
}

/** 設定の画面の枠。見出しの下に、まとまりを縦に並べてスクロールする */
@Composable
private fun SettingsPage(header: @Composable () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize()) {
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
private fun NavigationRow(title: String, value: String, valueColor: Color? = null, onClick: () -> Unit) {
    FormRow(onClick = onClick) {
        Text(title, Modifier.weight(1f))
        Text(value, color = valueColor ?: MaterialTheme.colorScheme.onSurfaceVariant)
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** 押すと何かをする行 (強調色の文字)。動いている間は右に回る印を出す */
@Composable
private fun ActionRow(title: String, isBusy: Boolean = false, enabled: Boolean = true, color: Color = AppTheme.accent, onClick: () -> Unit) {
    FormRow(onClick = if (enabled) onClick else null) {
        Text(title, color = if (enabled) color else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f), modifier = Modifier.weight(1f))
        if (isBusy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
    }
}

/** 結果や説明の行 */
@Composable
private fun MessageRow(text: String, color: Color? = null) {
    Text(
        text, style = MaterialTheme.typography.bodySmall, color = color ?: MaterialTheme.colorScheme.onSurfaceVariant,
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
            focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
            disabledContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
        ),
        modifier = modifier.fillMaxWidth(),
    )
}
