// Localizable.xcstringsから生成。直接編集せずmise run generate-localizationsを実行してください。
// 共有の Swift (RegzaCore) が画面に出す文言。CoreStringTable が、OS が入れた文言か元言語の文言を引く。

public enum CoreStrings {
    /// 元言語の文言 (OS が文言を入れていないときと、入れた中にないキーに使う)
    static let sourceTemplates: [String: String] = [
        "core_band_other": "その他",
        "core_band_terrestrial": "地デジ",
        "core_channel_list_unsupported": "この機種はチャンネル一覧の取得に対応していません。",
        "core_channel_tune_failed": "%@ に切り替えられませんでした。テレビの電源が入っているか確認してください。",
        "core_date_day_short": "d(E)",
        "core_day_after_tomorrow": "あさって",
        "core_day_today": "今日",
        "core_day_tomorrow": "明日",
        "core_error_command_rejected": "テレビがコマンドを拒否しました (%@)",
        "core_error_http_status": "HTTPエラー (%lld)",
        "core_error_invalid_host": "IPアドレスが正しくありません",
        "core_error_invalid_pin": "PIN が正しくありません。テレビに表示されている数字を確認してください",
        "core_error_invalid_response": "不正なレスポンスです",
        "core_error_not_configured": "接続先が設定されていません",
        "core_error_request_cancelled": "通信を取り消しました",
        "core_error_stream_unavailable": "配信の準備ができませんでした",
        "core_error_unauthorized": "認証に失敗しました。ユーザー名とパスワードを確認してください",
        "core_error_unsupported": "この機種は対応していません",
        "core_genre_anime": "アニメ",
        "core_genre_documentary": "ドキュメンタリー",
        "core_genre_drama": "ドラマ",
        "core_genre_hobby": "趣味・教育",
        "core_genre_information": "情報",
        "core_genre_movie": "映画",
        "core_genre_music": "音楽",
        "core_genre_news": "ニュース",
        "core_genre_sports": "スポーツ",
        "core_genre_theater": "劇場・公演",
        "core_genre_variety": "バラエティ",
        "core_genre_welfare": "福祉",
        "core_key_audio": "音声切替",
        "core_key_back": "戻る",
        "core_key_blue": "青",
        "core_key_broadband": "ブロードバンド",
        "core_key_channel_down": "チャンネル−",
        "core_key_channel_number": "CH番号",
        "core_key_channel_up": "チャンネル＋",
        "core_key_d_data": "dデータ",
        "core_key_display": "画面表示",
        "core_key_down": "下",
        "core_key_enter": "決定",
        "core_key_exit": "終了",
        "core_key_fast_forward": "早送り",
        "core_key_green": "緑",
        "core_key_guide": "番組表",
        "core_key_input": "入力切替",
        "core_key_jump_to_start": "始めにジャンプ",
        "core_key_left": "左",
        "core_key_mini_guide": "ミニ番組表",
        "core_key_multi_screen": "マルチ画面",
        "core_key_mute": "消音",
        "core_key_news_now": "今すぐニュース",
        "core_key_next_chapter": "次へスキップ",
        "core_key_page_down": "ページ下",
        "core_key_page_up": "ページ上",
        "core_key_pause": "一時停止",
        "core_key_play": "再生",
        "core_key_power": "電源",
        "core_key_previous_chapter": "前へスキップ",
        "core_key_program_info": "番組説明",
        "core_key_program_search": "番組検索",
        "core_key_quick": "クイック",
        "core_key_radio_data": "ラジオ/データ",
        "core_key_record": "録画",
        "core_key_recorded_list": "録画リスト",
        "core_key_red": "赤",
        "core_key_regza_menu": "レグザメニュー",
        "core_key_rewind": "巻き戻し",
        "core_key_right": "右",
        "core_key_screen_size": "画面サイズ",
        "core_key_settings": "設定メニュー",
        "core_key_skip_backward": "10秒戻し",
        "core_key_skip_forward": "30秒送り",
        "core_key_stop": "停止",
        "core_key_subtitle": "字幕",
        "core_key_terrestrial": "地デジ",
        "core_key_time_shift": "タイムシフト",
        "core_key_up": "上",
        "core_key_volume_down": "音量−",
        "core_key_volume_up": "音量＋",
        "core_key_yellow": "黄",
        "core_list_separator": "・",
        "core_locale": "ja_JP",
        "core_now_playing_broadcast": "放送",
        "core_now_playing_connected": "接続済み",
        "core_now_playing_external": "外部入力",
        "core_now_playing_recording": "録画",
        "core_now_playing_recording_channel": "録画 · %@",
        "core_now_playing_standby": "待機中",
        "core_now_playing_title_tv": "テレビ",
        "core_now_playing_title_watching": "視聴中",
        "core_player_preparing": "%@ の配信を準備しています…（20 秒ほど）",
        "core_player_unavailable": "このチャンネルは EPGStation で見られません。",
        "core_program_reserve_cancel_failed": "予約を取り消せませんでした: %@",
        "core_program_reserve_done": "予約しました。テレビの予約一覧に反映されるまで少しかかることがあります。",
        "core_program_reserve_rejected": "テレビが予約を受け付けませんでした (%@)。テレビの予約一覧や録画機器を確認してください。",
        "core_program_reserved": "録画予約済み",
        "core_program_series_reserved": "連ドラ予約済み",
        "core_program_series_reserved_repeat": "連ドラ予約済み（%@）",
        "core_program_time_with_minutes": "%1$@ · %2$lld分",
        "core_program_tuned": "テレビを%@に切り替えました。",
        "core_program_tuned_from_start": "テレビを%@に切り替えて、最初から再生しました。",
        "core_repeat_daily": "毎日",
        "core_repeat_monday_to_saturday": "月〜土",
        "core_repeat_other": "繰り返し",
        "core_repeat_weekdays": "月〜金",
        "core_repeat_weekly": "毎週",
        "core_reservation_cancel_failed": "「%1$@」の予約を取り消せませんでした: %2$@",
        "core_reservation_list_unsupported": "この機種は対応していません。",
        "core_search_hour": "%lld時",
        "core_search_hour_range": "%1$@〜%2$@",
        "core_search_on_air_until": "放送中 〜%@",
        "core_search_reason_cast": "%@ が出演",
        "core_search_reason_description": "説明に「%@」",
        "core_search_starts_at": "%1$@ %2$@〜",
        "core_server_guide_not_found": "見つかりませんでした。Mirakurun が動いているか、ポート %lld で待ち受けているか確認してください。",
        "core_server_guide_unlink_message": "番組名・番組表・番組表からの録画予約が使えなくなります。ライブ視聴（EPGStation）の連携も解除されます。",
        "core_server_guide_unlink_title": "Mirakurun との連携を解除しますか？",
        "core_server_stream_found": "Mirakurun と同じサーバーで EPGStation が見つかりました。よければ「保存」を押してください。",
        "core_server_stream_not_found": "見つかりませんでした。EPGStation が動いているか、ポート %lld で待ち受けているか確認してください。",
        "core_server_stream_unlink_message": "アプリでのライブ視聴が使えなくなります。",
        "core_server_stream_unlink_title": "EPGStation との連携を解除しますか？",
        "core_settings_password_entered": "(入力済み)",
        "core_setup_not_configured": "未設定",
        "core_time_range": "%1$@ %2$@ 〜 %3$@",
        "core_tv_connected": "接続できました",
        "core_tv_connected_detail": "接続できました: %@",
        "core_tv_pairing_unsupported": "この機種は PIN 登録に対応していません。下の「ユーザー名とパスワードを入力」から設定してください。",
        "core_tv_pin_required": "PIN の登録が必要",
        "core_tv_scan_not_found": "見つかりませんでした。テレビの電源が入っているか、テレビと同じ Wi-Fi につながっているか確認してください。",
        "core_tv_scan_not_found_ios": "見つかりませんでした。テレビの電源が入っているか、iPhone の「設定」→「プライバシーとセキュリティ」→「ローカルネットワーク」でこのアプリが許可されているか確認してください。",
    ]

    public static var bandOther: String { CoreStringTable.text("core_band_other") }

    public static var bandTerrestrial: String { CoreStringTable.text("core_band_terrestrial") }

    public static var channelListUnsupported: String { CoreStringTable.text("core_channel_list_unsupported") }

    public static func channelTuneFailed(_ value1: String) -> String {
        CoreStringTable.text("core_channel_tune_failed", [.string(value1)])
    }

    public static var dateDayShort: String { CoreStringTable.text("core_date_day_short") }

    public static var dayAfterTomorrow: String { CoreStringTable.text("core_day_after_tomorrow") }

    public static var dayToday: String { CoreStringTable.text("core_day_today") }

    public static var dayTomorrow: String { CoreStringTable.text("core_day_tomorrow") }

    public static func errorCommandRejected(_ value1: String) -> String {
        CoreStringTable.text("core_error_command_rejected", [.string(value1)])
    }

    public static func errorHttpStatus(_ value1: Int) -> String {
        CoreStringTable.text("core_error_http_status", [.int(value1)])
    }

    public static var errorInvalidHost: String { CoreStringTable.text("core_error_invalid_host") }

    public static var errorInvalidPin: String { CoreStringTable.text("core_error_invalid_pin") }

    public static var errorInvalidResponse: String { CoreStringTable.text("core_error_invalid_response") }

    public static var errorNotConfigured: String { CoreStringTable.text("core_error_not_configured") }

    public static var errorRequestCancelled: String { CoreStringTable.text("core_error_request_cancelled") }

    public static var errorStreamUnavailable: String { CoreStringTable.text("core_error_stream_unavailable") }

    public static var errorUnauthorized: String { CoreStringTable.text("core_error_unauthorized") }

    public static var errorUnsupported: String { CoreStringTable.text("core_error_unsupported") }

    public static var genreAnime: String { CoreStringTable.text("core_genre_anime") }

    public static var genreDocumentary: String { CoreStringTable.text("core_genre_documentary") }

    public static var genreDrama: String { CoreStringTable.text("core_genre_drama") }

    public static var genreHobby: String { CoreStringTable.text("core_genre_hobby") }

    public static var genreInformation: String { CoreStringTable.text("core_genre_information") }

    public static var genreMovie: String { CoreStringTable.text("core_genre_movie") }

    public static var genreMusic: String { CoreStringTable.text("core_genre_music") }

    public static var genreNews: String { CoreStringTable.text("core_genre_news") }

    public static var genreSports: String { CoreStringTable.text("core_genre_sports") }

    public static var genreTheater: String { CoreStringTable.text("core_genre_theater") }

    public static var genreVariety: String { CoreStringTable.text("core_genre_variety") }

    public static var genreWelfare: String { CoreStringTable.text("core_genre_welfare") }

    public static var keyAudio: String { CoreStringTable.text("core_key_audio") }

    public static var keyBack: String { CoreStringTable.text("core_key_back") }

    public static var keyBlue: String { CoreStringTable.text("core_key_blue") }

    public static var keyBroadband: String { CoreStringTable.text("core_key_broadband") }

    public static var keyChannelDown: String { CoreStringTable.text("core_key_channel_down") }

    public static var keyChannelNumber: String { CoreStringTable.text("core_key_channel_number") }

    public static var keyChannelUp: String { CoreStringTable.text("core_key_channel_up") }

    public static var keyDData: String { CoreStringTable.text("core_key_d_data") }

    public static var keyDisplay: String { CoreStringTable.text("core_key_display") }

    public static var keyDown: String { CoreStringTable.text("core_key_down") }

    public static var keyEnter: String { CoreStringTable.text("core_key_enter") }

    public static var keyExit: String { CoreStringTable.text("core_key_exit") }

    public static var keyFastForward: String { CoreStringTable.text("core_key_fast_forward") }

    public static var keyGreen: String { CoreStringTable.text("core_key_green") }

    public static var keyGuide: String { CoreStringTable.text("core_key_guide") }

    public static var keyInput: String { CoreStringTable.text("core_key_input") }

    public static var keyJumpToStart: String { CoreStringTable.text("core_key_jump_to_start") }

    public static var keyLeft: String { CoreStringTable.text("core_key_left") }

    public static var keyMiniGuide: String { CoreStringTable.text("core_key_mini_guide") }

    public static var keyMultiScreen: String { CoreStringTable.text("core_key_multi_screen") }

    public static var keyMute: String { CoreStringTable.text("core_key_mute") }

    public static var keyNewsNow: String { CoreStringTable.text("core_key_news_now") }

    public static var keyNextChapter: String { CoreStringTable.text("core_key_next_chapter") }

    public static var keyPageDown: String { CoreStringTable.text("core_key_page_down") }

    public static var keyPageUp: String { CoreStringTable.text("core_key_page_up") }

    public static var keyPause: String { CoreStringTable.text("core_key_pause") }

    public static var keyPlay: String { CoreStringTable.text("core_key_play") }

    public static var keyPower: String { CoreStringTable.text("core_key_power") }

    public static var keyPreviousChapter: String { CoreStringTable.text("core_key_previous_chapter") }

    public static var keyProgramInfo: String { CoreStringTable.text("core_key_program_info") }

    public static var keyProgramSearch: String { CoreStringTable.text("core_key_program_search") }

    public static var keyQuick: String { CoreStringTable.text("core_key_quick") }

    public static var keyRadioData: String { CoreStringTable.text("core_key_radio_data") }

    public static var keyRecord: String { CoreStringTable.text("core_key_record") }

    public static var keyRecordedList: String { CoreStringTable.text("core_key_recorded_list") }

    public static var keyRed: String { CoreStringTable.text("core_key_red") }

    public static var keyRegzaMenu: String { CoreStringTable.text("core_key_regza_menu") }

    public static var keyRewind: String { CoreStringTable.text("core_key_rewind") }

    public static var keyRight: String { CoreStringTable.text("core_key_right") }

    public static var keyScreenSize: String { CoreStringTable.text("core_key_screen_size") }

    public static var keySettings: String { CoreStringTable.text("core_key_settings") }

    public static var keySkipBackward: String { CoreStringTable.text("core_key_skip_backward") }

    public static var keySkipForward: String { CoreStringTable.text("core_key_skip_forward") }

    public static var keyStop: String { CoreStringTable.text("core_key_stop") }

    public static var keySubtitle: String { CoreStringTable.text("core_key_subtitle") }

    public static var keyTerrestrial: String { CoreStringTable.text("core_key_terrestrial") }

    public static var keyTimeShift: String { CoreStringTable.text("core_key_time_shift") }

    public static var keyUp: String { CoreStringTable.text("core_key_up") }

    public static var keyVolumeDown: String { CoreStringTable.text("core_key_volume_down") }

    public static var keyVolumeUp: String { CoreStringTable.text("core_key_volume_up") }

    public static var keyYellow: String { CoreStringTable.text("core_key_yellow") }

    public static var listSeparator: String { CoreStringTable.text("core_list_separator") }

    public static var locale: String { CoreStringTable.text("core_locale") }

    public static var nowPlayingBroadcast: String { CoreStringTable.text("core_now_playing_broadcast") }

    public static var nowPlayingConnected: String { CoreStringTable.text("core_now_playing_connected") }

    public static var nowPlayingExternal: String { CoreStringTable.text("core_now_playing_external") }

    public static var nowPlayingRecording: String { CoreStringTable.text("core_now_playing_recording") }

    public static func nowPlayingRecordingChannel(_ value1: String) -> String {
        CoreStringTable.text("core_now_playing_recording_channel", [.string(value1)])
    }

    public static var nowPlayingStandby: String { CoreStringTable.text("core_now_playing_standby") }

    public static var nowPlayingTitleTv: String { CoreStringTable.text("core_now_playing_title_tv") }

    public static var nowPlayingTitleWatching: String { CoreStringTable.text("core_now_playing_title_watching") }

    public static func playerPreparing(_ value1: String) -> String {
        CoreStringTable.text("core_player_preparing", [.string(value1)])
    }

    public static var playerUnavailable: String { CoreStringTable.text("core_player_unavailable") }

    public static func programReserveCancelFailed(_ value1: String) -> String {
        CoreStringTable.text("core_program_reserve_cancel_failed", [.string(value1)])
    }

    public static var programReserveDone: String { CoreStringTable.text("core_program_reserve_done") }

    public static func programReserveRejected(_ value1: String) -> String {
        CoreStringTable.text("core_program_reserve_rejected", [.string(value1)])
    }

    public static var programReserved: String { CoreStringTable.text("core_program_reserved") }

    public static var programSeriesReserved: String { CoreStringTable.text("core_program_series_reserved") }

    public static func programSeriesReservedRepeat(_ value1: String) -> String {
        CoreStringTable.text("core_program_series_reserved_repeat", [.string(value1)])
    }

    public static func programTimeWithMinutes(_ value1: String, _ value2: Int) -> String {
        CoreStringTable.text("core_program_time_with_minutes", [.string(value1), .int(value2)])
    }

    public static func programTuned(_ value1: String) -> String {
        CoreStringTable.text("core_program_tuned", [.string(value1)])
    }

    public static func programTunedFromStart(_ value1: String) -> String {
        CoreStringTable.text("core_program_tuned_from_start", [.string(value1)])
    }

    public static var repeatDaily: String { CoreStringTable.text("core_repeat_daily") }

    public static var repeatMondayToSaturday: String { CoreStringTable.text("core_repeat_monday_to_saturday") }

    public static var repeatOther: String { CoreStringTable.text("core_repeat_other") }

    public static var repeatWeekdays: String { CoreStringTable.text("core_repeat_weekdays") }

    public static var repeatWeekly: String { CoreStringTable.text("core_repeat_weekly") }

    public static func reservationCancelFailed(_ value1: String, _ value2: String) -> String {
        CoreStringTable.text("core_reservation_cancel_failed", [.string(value1), .string(value2)])
    }

    public static var reservationListUnsupported: String { CoreStringTable.text("core_reservation_list_unsupported") }

    public static func searchHour(_ value1: Int) -> String {
        CoreStringTable.text("core_search_hour", [.int(value1)])
    }

    public static func searchHourRange(_ value1: String, _ value2: String) -> String {
        CoreStringTable.text("core_search_hour_range", [.string(value1), .string(value2)])
    }

    public static func searchOnAirUntil(_ value1: String) -> String {
        CoreStringTable.text("core_search_on_air_until", [.string(value1)])
    }

    public static func searchReasonCast(_ value1: String) -> String {
        CoreStringTable.text("core_search_reason_cast", [.string(value1)])
    }

    public static func searchReasonDescription(_ value1: String) -> String {
        CoreStringTable.text("core_search_reason_description", [.string(value1)])
    }

    public static func searchStartsAt(_ value1: String, _ value2: String) -> String {
        CoreStringTable.text("core_search_starts_at", [.string(value1), .string(value2)])
    }

    public static func serverGuideNotFound(_ value1: Int) -> String {
        CoreStringTable.text("core_server_guide_not_found", [.int(value1)])
    }

    public static var serverGuideUnlinkMessage: String { CoreStringTable.text("core_server_guide_unlink_message") }

    public static var serverGuideUnlinkTitle: String { CoreStringTable.text("core_server_guide_unlink_title") }

    public static var serverStreamFound: String { CoreStringTable.text("core_server_stream_found") }

    public static func serverStreamNotFound(_ value1: Int) -> String {
        CoreStringTable.text("core_server_stream_not_found", [.int(value1)])
    }

    public static var serverStreamUnlinkMessage: String { CoreStringTable.text("core_server_stream_unlink_message") }

    public static var serverStreamUnlinkTitle: String { CoreStringTable.text("core_server_stream_unlink_title") }

    public static var settingsPasswordEntered: String { CoreStringTable.text("core_settings_password_entered") }

    public static var setupNotConfigured: String { CoreStringTable.text("core_setup_not_configured") }

    public static func timeRange(_ value1: String, _ value2: String, _ value3: String) -> String {
        CoreStringTable.text("core_time_range", [.string(value1), .string(value2), .string(value3)])
    }

    public static var tvConnected: String { CoreStringTable.text("core_tv_connected") }

    public static func tvConnectedDetail(_ value1: String) -> String {
        CoreStringTable.text("core_tv_connected_detail", [.string(value1)])
    }

    public static var tvPairingUnsupported: String { CoreStringTable.text("core_tv_pairing_unsupported") }

    public static var tvPinRequired: String { CoreStringTable.text("core_tv_pin_required") }

    public static var tvScanNotFound: String { CoreStringTable.text("core_tv_scan_not_found") }

    public static var tvScanNotFoundIos: String { CoreStringTable.text("core_tv_scan_not_found_ios") }
}
