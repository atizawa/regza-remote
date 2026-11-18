// 画面の組み立て (iOS の AppUI に対応)。いちばん外側の画面 (AppRoot)・タブ・タブの中で開く画面の移り変わり (AppRoutes) を受け持ち、
// 機能の画面のモジュール (ui/<機能>) をつなぐ。state は Swift の窓口 (core:bridge) から受け取って画面に渡す。
// アプリ本体 (app: 起動・appservices・ウィジェット・通知) は読み込まず、要るもの (Live Updates の実装など) は app から受け取る
plugins {
    id("regza.android.ui")
}

dependencies {
    // Swift の窓口 (state の購読とすべての送り先)。組み立てだけが使う
    implementation(project(":core:bridge"))
    // 機能の画面のモジュール (settings.gradle.kts が ui/ の下から読んだもの。共通の部品と組み立て自身を除く)
    rootProject.subprojects
        .filter { it.path.startsWith(":ui:") && it.path != ":ui:common" && it.path != project.path }
        .forEach { implementation(project(it.path)) }
    implementation(libs.androidx.lifecycle.runtime.compose)
    // タブの中の画面の移り変わり: 共有の AppViewModel が持つ path を back stack として渡す
    implementation(libs.androidx.navigation3.runtime)
    implementation(libs.androidx.navigation3.ui)
}
