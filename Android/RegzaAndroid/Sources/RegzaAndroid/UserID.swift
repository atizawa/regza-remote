import RegzaApp

/// このアプリ用のユーザー ID を新しく作る (MAC アドレスの形)。Kotlin の保存先が、初めて使うときに作って保存する
public func regzaMakeUserID() -> String {
    PairingUserID.make()
}
