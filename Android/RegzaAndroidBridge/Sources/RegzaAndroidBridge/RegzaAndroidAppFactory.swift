import RegzaApp

/// Android の通信実装を保持し、Kotlin の保存先からアプリを組み立てる。
public final class RegzaAndroidAppFactory {
    let httpTransport: any HTTPTransport

    init(transport: any HTTPTransport) {
        httpTransport = transport
    }

    public func makeApp(storage: any RegzaAndroidStorage) -> RegzaAndroidApp {
        RegzaAndroidApp(storage: storage, httpTransport: httpTransport)
    }
}
