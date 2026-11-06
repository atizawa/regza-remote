// swift-java の Java 側 (SwiftKitCore)。Maven で配られていないので、SwiftPM が取ってきた同じ版のソースをここでコンパイルする
// (版は RegzaAndroid/Package.swift の swift-java の revision で決まる。mise run build-swift で取ってくる)。
// Android の API にはない jdk.jfr を注釈で使っているので、app ではなくふつうの Java のライブラリとしてコンパイルする
plugins {
    `java-library`
}

val swiftJava = "../.build/swift/checkouts/swift-java/SwiftKitCore/src/main"

sourceSets.main {
    java.srcDir("$swiftJava/java")
    resources.srcDir("$swiftJava/resources")
}

// ソースとリソースは app の buildSwift (mise run build-swift) が SwiftPM で取ってくる
tasks.named("processResources") { dependsOn(":app:buildSwift") }

tasks.withType<JavaCompile>().configureEach {
    dependsOn(":app:buildSwift")
    // swift-java の設定と同じく Java 11 で使えるようにする。JDK は決め打ちせず、Gradle を動かしている JDK を使う
    // (コマンドラインでは mise の JDK 21、Android Studio では付いてくる JDK)
    options.release.set(11)
}
