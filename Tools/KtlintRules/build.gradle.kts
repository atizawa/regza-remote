plugins {
    alias(libs.plugins.kotlin.jvm)
}

// mise.toml の ktlint と同じ版を、mise のビルドタスクから渡す。
val ktlintVersion = providers.gradleProperty("ktlintVersion").get()

dependencies {
    compileOnly("com.pinterest.ktlint:ktlint-cli-ruleset-core:$ktlintVersion")
    compileOnly("com.pinterest.ktlint:ktlint-rule-engine-core:$ktlintVersion")
    testImplementation("com.pinterest.ktlint:ktlint-test:$ktlintVersion")
    testImplementation("com.pinterest.ktlint:ktlint-cli-ruleset-core:$ktlintVersion")
    testImplementation("org.junit.jupiter:junit-jupiter:5.14.1")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher:1.14.1")
    testRuntimeOnly("org.slf4j:slf4j-simple:2.0.17")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        // ktlint 1.8 の Kotlin ランタイムで読み込む。
        languageVersion = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2
        apiVersion = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

tasks.test { useJUnitPlatform() }
tasks.jar { archiveFileName.set("regza-ktlint-rules.jar") }
