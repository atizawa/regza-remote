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

java {
    toolchain { languageVersion.set(JavaLanguageVersion.of(21)) }
}

tasks.withType<JavaCompile>().configureEach {
    // swift-java の設定と同じく Java 11 で使えるようにする
    options.release.set(11)
}
