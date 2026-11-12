package com.example.regzaremote.bridge

import com.example.regzaremote.core.RegzaAndroidBridge
import com.example.regzaremote.core.URL

/** Swift の URL を、Android のプレイヤーへ渡す文字列に変換する。 */
fun streamURLString(url: URL): String = RegzaAndroidBridge.regzaURLString(url)
