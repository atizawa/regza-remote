// iOS・Android・CLI が import RegzaPresentation だけで、プレゼンテーション層のすべてのモジュール (共通・機能ごと・アプリ全体) と
// UI の型 (SharedModels) を使えるようにする。画面のモジュールは、これを使わずに自分の機能のモジュールだけを読み込む
@_exported public import AppPresentation
@_exported public import ChannelsPresentation
@_exported public import GuidePresentation
@_exported public import PlayerPresentation
@_exported public import PresentationCore
@_exported public import ProgramPresentation
@_exported public import ReservationsPresentation
@_exported public import SettingsPresentation
