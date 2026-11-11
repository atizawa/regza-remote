# RegzaSharedModels

UI (iOS の SwiftUI と Android の Compose) で使う型。Domain の UseCase が Data から作る。Repository と UseCase の間で使う XXXData は、このモジュールや ViewModel に持ち込まない。

UseCase の公開するモデルは SharedModels に揃える。選局・録画予約などは SharedModel の ID から UseCase 内で元の Data を解決し、Repository に渡す。接続設定は ConnectionItem と ConnectionData を相互に変換する。

Android からも使うので、swift-java で Java のクラスにできる形にする:
入れ子の型・generics・protocol を使わず、プロパティは String・数・Bool・配列・Optional・ほかの SharedModels にする。
時刻の表記などの文字列は、ここに入れて渡す (OS ごとに書式を作り直さない)。
