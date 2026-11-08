# RegzaSharedModels

UI (iOS の SwiftUI と Android の Compose) で使う型。Domain の UseCase がエンティティから作る。

Android からも使うので、swift-java で Java のクラスにできる形にする:
入れ子の型・generics・protocol を使わず、プロパティは String・数・Bool・配列・Optional・ほかの SharedModels にする。
時刻の表記などの文字列は、ここに入れて渡す (OS ごとに書式を作り直さない)。
