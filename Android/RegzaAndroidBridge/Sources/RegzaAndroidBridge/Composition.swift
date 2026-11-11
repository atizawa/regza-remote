import RegzaApp

extension RegzaAndroidAppFactory {
    public convenience init(httpTransport: any HTTPTransport) {
        self.init(transport: httpTransport)
    }
}

extension RegzaAndroidApp {
    /// OS 固有の起動処理が通信方式を渡す。Swift 用の入口なので Java への生成対象から外す。
    public convenience init(storage: any RegzaAndroidStorage, httpTransport: any HTTPTransport) {
        self.init(
            appViewModel: onMainActor {
                let managers = makeStorageManagers(storage)
                let appViewModel = AppFactory.makeLiveAppViewModel(
                    secureStorageManager: managers.secureStorageManager,
                    preferencesManager: managers.preferencesManager, transport: httpTransport)
                return appViewModel
            })
    }
}
