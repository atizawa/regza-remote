import FoundationCheck
import SwiftJava

/// テスト専用: 端末のテスト (FoundationICUTest) の FoundationCheck.run() から呼ぶ。
/// この .so は debug の APK にだけ入る (build-swift.sh が app/src/debug/jniLibs に置く)
@_cdecl("Java_com_example_regzaremote_FoundationCheck_run")
public func foundationCheckRun(_ environment: UnsafeMutablePointer<JNIEnv?>, _ object: jobject?) -> jstring? {
    regzaFoundationCheck().withCString { environment.pointee!.pointee.NewStringUTF(environment, $0) }
}
