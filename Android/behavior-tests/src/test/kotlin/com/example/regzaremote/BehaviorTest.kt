package com.example.regzaremote

import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.ProgramListAction
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.core.SettingsAction
import com.example.regzaremote.core.SettingsPage
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * アプリの振る舞いを、Android と同じ道 (Kotlin → swift-java のつなぎ → 窓口 → 共有の ViewModel) で確かめる。
 * 画面は描かず、操作を送って ViewModel の state を見る
 */
class BehaviorTest {
    @Test
    fun startsWithRemoteWhenTVIsRegistered() {
        val sample = SampleApp()
        val state = sample.until(sample.app.appStates())
        assertEquals("remote", state.tab.rawValue)
        assertTrue(!state.isShowingSettings)
        // 見本のテレビの登録と、PIN 登録に使う ID を保存先に書いた
        assertEquals("192.0.2.10", sample.storage.values["host"])
        // アプリと同じく、画面が見えている間は、いま映っているものを取り直す
        sample.send(RemoteAction.startPolling())
        val remote = sample.until(sample.app.remoteStates()) { it.nowPlaying.isPresent }
        assertEquals("見本の番組", remote.nowPlaying.get().title)
        sample.send(RemoteAction.stopPolling())
    }

    @Test
    fun keysAreSentToTheRemote() {
        val sample = SampleApp()
        val before = sample.until(sample.app.remoteStates())
        sample.send(RemoteAction.press(RegzaKey.power()))
        sample.until(sample.app.remoteStates()) { it.tapCount > before.tapCount }
    }

    @Test
    fun channelListShowsSampleChannelsAndOpensPrograms() {
        val sample = SampleApp()
        sample.send(AppAction.selectTab(AppTab.channels()))
        sample.send(ChannelListAction.appear())
        val list = sample.until(sample.app.channelListStates()) { it.rows.isNotEmpty() }
        assertEquals("テスト局１", list.rows.first().name)

        // チャンネルの番組表を開く (タブの path に積む)
        val code = list.rows.first().code
        val route = AppRoute.channelPrograms(code)
        sample.send(AppAction.push(route))
        sample.until(sample.app.appStates()) { it.path(AppTab.channels()).size == 1 }
        sample.send(ProgramListAction.appear())
        val programs = sample.until(sample.app.programListStates(route)) { it.days.isPresent }
        assertEquals("テスト局１", programs.channelName)
        assertTrue(programs.days.get().isNotEmpty())

        // 戻る
        sample.send(AppAction.pop())
        sample.until(sample.app.appStates()) { it.path(AppTab.channels()).isEmpty() }
    }

    @Test
    fun guideSelectsAnotherDay() {
        val sample = SampleApp()
        sample.send(AppAction.selectTab(AppTab.guide()))
        sample.send(GuideGridAction.load())
        val guide = sample.until(sample.app.guideGridStates()) { it.days.size > 1 && it.columns.isNotEmpty() }
        assertTrue(guide.isToday)

        sample.send(GuideGridAction.selectDay(guide.days[1].date))
        val tomorrow = sample.until(sample.app.guideGridStates()) { it.selectedDayIndex == 1L }
        assertTrue(!tomorrow.isToday)
    }

    @Test
    fun settingsOpenPagesAndClose() {
        val sample = SampleApp()
        sample.send(AppAction.showSettings())
        sample.until(sample.app.settingsStates()) { it.path.isEmpty() }

        sample.send(SettingsAction.openPage(SettingsPage.guide()))
        sample.until(sample.app.settingsStates()) { it.path.map { page -> page.rawValue } == listOf("guide") }
        sample.send(SettingsAction.back())
        sample.until(sample.app.settingsStates()) { it.path.isEmpty() }

        sample.send(SettingsAction.close())
        assertTrue(sample.closed(sample.app.settingsStates()))
    }
}
