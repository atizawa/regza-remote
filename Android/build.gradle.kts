plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.jvm) apply false
}

// Swift のビルド (app の buildSwift・behavior-tests の buildJvmHost) が呼ぶ mise の場所。
// Android Studio から動かすと PATH に mise がないことがあるので、よく入っている場所から探す (なければ PATH の mise)。
// 呼ぶ側は MISE_EXECUTABLE でこの場所を scripts/swift-toolchain.sh に渡し、同じ mise の Swift を使わせる
// (探す場所を変えるときは、scripts/swift-toolchain.sh の候補も一緒に変える)
extra["mise"] = listOf("/opt/homebrew/bin/mise", "/usr/local/bin/mise", "${System.getProperty("user.home")}/.local/bin/mise")
    .firstOrNull { File(it).canExecute() } ?: "mise"
