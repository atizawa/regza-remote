package com.example.regzaremote.ui.components

import com.example.regzaremote.core.RegzaKey

/** 画面で使うキー。RegzaKey は Swift の値なので、描き直すたびに作らず、ここで 1 度だけ作る (リモコンとミニプレーヤーで使う) */
object RemoteKeys {
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
