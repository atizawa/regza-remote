package com.example.regzaremote.ui.program

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.ProgramItem
import com.example.regzaremote.core.ProgramListAction
import com.example.regzaremote.core.ProgramListState
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.DesignDimensions
import com.example.regzaremote.localization.AppStrings
import com.example.regzaremote.presentation.program.ProgramApp
import com.example.regzaremote.presentation.program.ProgramSend
import com.example.regzaremote.ui.components.EmptyState
import com.example.regzaremote.ui.components.Loading
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.Note
import com.example.regzaremote.ui.components.RefreshBox
import com.example.regzaremote.ui.components.ReservedBadge
import com.example.regzaremote.ui.components.RowDivider
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.SectionHeader
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.components.sectionRowShape
import com.example.regzaremote.ui.preview.FAKE_CHANNEL
import com.example.regzaremote.ui.preview.FakePreview

/** 1 チャンネルの番組表 (state と操作は ProgramListViewModel の ProgramListState・ProgramListAction)。日付ごとのまとまりに分けて並べる */
@Composable
fun ProgramListScreen(list: ProgramListState, onBack: (() -> Unit)?, send: ProgramSend) {
    LaunchedEffect(list.channelCode) { send(ProgramListAction.appear()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(list.channelName, onBack)
        val message = list.loadErrorMessage.orElse(null)
        // 読み込む前は nil
        val days = list.days.orElse(null)
        when {
            days != null && days.isEmpty() -> EmptyState(AppStrings.guideEmpty, AppStrings.guideChannelEmpty)

            days != null -> RefreshBox(isLoading = list.isLoading, onRefresh = { send(ProgramListAction.reload()) }) {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = DesignDimensions.spacingOuter,
                        top = DesignDimensions.spacingOuter,
                        end = DesignDimensions.spacingOuter,
                        bottom =
                            DesignDimensions.spacingOuter + LocalMiniPlayerInset.current,
                    ),
                ) {
                    days.forEach { day ->
                        item(key = "day-${day.label}") { SectionHeader(day.label, Modifier.padding(top = 8.dp, bottom = 6.dp)) }
                        val programs = day.programs.toList()
                        itemsIndexed(programs, key = { _, program -> program.id }) { index, program ->
                            Column(Modifier.background(AppTheme.surface, sectionRowShape(index, programs.size))) {
                                ProgramRow(program, send)
                                if (index < programs.size - 1) RowDivider()
                            }
                        }
                        item(key = "space-${day.label}") { Box(Modifier.padding(bottom = DesignDimensions.spacingItem)) }
                    }
                }
            }

            message != null -> EmptyState(AppStrings.guideLoadFailed, message) {
                TextButton(onClick = { send(ProgramListAction.reload()) }) { Text(AppStrings.commonRetry) }
            }

            else -> Loading()
        }
    }
}

@Composable
private fun ProgramRow(program: ProgramItem, send: ProgramSend) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { send.push(AppRoute.programDetail(program.id, program.channelCode)) }
            .padding(start = DesignDimensions.spacingOuter, end = 8.dp, top = 10.dp, bottom = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            program.startText,
            style = MaterialTheme.typography.bodyMedium,
            color = if (program.isOnAir) AppTheme.accent else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(48.dp),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(program.name, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                if (program.isReserved) ReservedBadge(compact = true)
                if (program.isOnAir) Text(AppStrings.programOnAir, style = MaterialTheme.typography.bodySmall, color = AppTheme.accent)
                program.genreName.orElse(null)?.let { Note(it) }
            }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Preview(name = "1 局の番組表")
@Composable
private fun ProgramListScreenPreview() = FakePreview<ProgramApp>(prepareRoutes = true, setUp = {
    it.push(AppRoute.channelPrograms(FAKE_CHANNEL))
    it(ProgramListAction.appear())
}) { app ->
    val route = remember { AppRoute.channelPrograms(FAKE_CHANNEL) }
    rememberState(app) { app.programListStates(route) }?.let { ProgramListScreen(it, onBack = {}, app) }
}
