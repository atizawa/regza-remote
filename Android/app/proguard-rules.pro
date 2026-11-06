# swift-java の SwiftKitCore は、Android にない jdk.jfr の注釈を付けている (動くときには使わない)
-dontwarn jdk.jfr.**

# swift-java が作ったクラスと SwiftKitCore は、Swift (JNI) から名前で探して呼ばれるので、名前を変えずに残す
-keep class org.swift.swiftkit.** { *; }
-keep class com.example.regzaremote.core.** { *; }
