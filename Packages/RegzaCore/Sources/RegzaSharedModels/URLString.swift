public import Foundation

/// URL を文字列にする (Android で、配信の URL をプレイヤーに渡す)。
/// swift-java は enum の値にしか使っていない型の Java のクラスを作らないので、共有の UI の型と一緒に URL の Java のクラスを作らせる役目もある
/// (ほかのモジュールの Foundation の型のつなぎは、ここで作ったものを使う)
public func urlString(_ url: URL) -> String { url.absoluteString }
