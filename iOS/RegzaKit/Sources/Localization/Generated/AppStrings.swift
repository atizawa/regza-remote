// Localizable.xcstringsから生成。直接編集せずmise run generate-localizationsを実行してください。
import Foundation

public enum AppStrings {
    public static var activityDisabledHelp: String { String(localized: "activity_disabled_help", bundle: .module) }

    public static var activityHelp: String { String(localized: "activity_help", bundle: .module) }

    public static var activityTitle: String { String(localized: "activity_title", bundle: .module) }

    public static var appName: String { String(localized: "app_name", bundle: .module) }

    public static var appearanceDark: String { String(localized: "appearance_dark", bundle: .module) }

    public static var appearanceLight: String { String(localized: "appearance_light", bundle: .module) }

    public static var appearanceSystem: String { String(localized: "appearance_system", bundle: .module) }

    public static var appearanceTitle: String { String(localized: "appearance_title", bundle: .module) }

    public static var broadcastTitle: String { String(localized: "broadcast_title", bundle: .module) }

    public static func channelGuideTitle(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("channel_guide_title", bundle: .module, comment: ""), value1)
    }

    public static var channelListTitle: String { String(localized: "channel_list_title", bundle: .module) }

    public static var channelLoadFailed: String { String(localized: "channel_load_failed", bundle: .module) }

    public static var channelMissing: String { String(localized: "channel_missing", bundle: .module) }

    public static func channelOnAir(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("channel_on_air", bundle: .module, comment: ""), value1)
    }

    public static var channelSwitch: String { String(localized: "channel_switch", bundle: .module) }

    public static var channelSwitchWatch: String { String(localized: "channel_switch_watch", bundle: .module) }

    public static var channelWatching: String { String(localized: "channel_watching", bundle: .module) }

    public static var commonBack: String { String(localized: "common_back", bundle: .module) }

    public static var commonCancel: String { String(localized: "common_cancel", bundle: .module) }

    public static var commonClose: String { String(localized: "common_close", bundle: .module) }

    public static var commonConfigure: String { String(localized: "common_configure", bundle: .module) }

    public static var commonDisplay: String { String(localized: "common_display", bundle: .module) }

    public static var commonOpenSettings: String { String(localized: "common_open_settings", bundle: .module) }

    public static var commonRegister: String { String(localized: "common_register", bundle: .module) }

    public static var commonReload: String { String(localized: "common_reload", bundle: .module) }

    public static var commonRetry: String { String(localized: "common_retry", bundle: .module) }

    public static var commonSave: String { String(localized: "common_save", bundle: .module) }

    public static var commonSelected: String { String(localized: "common_selected", bundle: .module) }

    public static var guideChannelEmpty: String { String(localized: "guide_channel_empty", bundle: .module) }

    public static var guideConnectionHelp: String { String(localized: "guide_connection_help", bundle: .module) }

    public static var guideEmpty: String { String(localized: "guide_empty", bundle: .module) }

    public static var guideLoadFailed: String { String(localized: "guide_load_failed", bundle: .module) }

    public static var guideSetupHelp: String { String(localized: "guide_setup_help", bundle: .module) }

    public static var guideSetupTitle: String { String(localized: "guide_setup_title", bundle: .module) }

    public static var liveBadge: String { String(localized: "live_badge", bundle: .module) }

    public static var liveRetry: String { String(localized: "live_retry", bundle: .module) }

    public static var liveTitle: String { String(localized: "live_title", bundle: .module) }

    public static var networkPermissionAllow: String { String(localized: "network_permission_allow", bundle: .module) }

    public static var networkPermissionHelp: String { String(localized: "network_permission_help", bundle: .module) }

    public static var networkPermissionTitle: String { String(localized: "network_permission_title", bundle: .module) }

    public static var playerFromStart: String { String(localized: "player_from_start", bundle: .module) }

    public static var playerNowPlaying: String { String(localized: "player_now_playing", bundle: .module) }

    public static var playerPlay: String { String(localized: "player_play", bundle: .module) }

    public static var playerProgramFromStart: String { String(localized: "player_program_from_start", bundle: .module) }

    public static var playerWatch: String { String(localized: "player_watch", bundle: .module) }

    public static var programChannelGuide: String { String(localized: "program_channel_guide", bundle: .module) }

    public static var programDescription: String { String(localized: "program_description", bundle: .module) }

    public static var programDetails: String { String(localized: "program_details", bundle: .module) }

    public static var programMissing: String { String(localized: "program_missing", bundle: .module) }

    public static var programOnAir: String { String(localized: "program_on_air", bundle: .module) }

    public static func programOnAirTime(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("program_on_air_time", bundle: .module, comment: ""), value1)
    }

    public static var programOpenDetails: String { String(localized: "program_open_details", bundle: .module) }

    public static func programTimeRange(_ value1: String, _ value2: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("program_time_range", bundle: .module, comment: ""), value1, value2)
    }

    public static func recordingChannel(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("recording_channel", bundle: .module, comment: ""), value1)
    }

    public static var recordingTitle: String { String(localized: "recording_title", bundle: .module) }

    public static var remoteConnecting: String { String(localized: "remote_connecting", bundle: .module) }

    public static var remoteConnectionFailed: String { String(localized: "remote_connection_failed", bundle: .module) }

    public static var remoteEnter: String { String(localized: "remote_enter", bundle: .module) }

    public static var remoteMore: String { String(localized: "remote_more", bundle: .module) }

    public static var remotePlayback: String { String(localized: "remote_playback", bundle: .module) }

    public static var remotePowerOn: String { String(localized: "remote_power_on", bundle: .module) }

    public static var remoteSearching: String { String(localized: "remote_searching", bundle: .module) }

    public static var remoteSetupHelp: String { String(localized: "remote_setup_help", bundle: .module) }

    public static var remoteTvGuide: String { String(localized: "remote_tv_guide", bundle: .module) }

    public static var remoteUnconfigured: String { String(localized: "remote_unconfigured", bundle: .module) }

    public static var remoteVolume: String { String(localized: "remote_volume", bundle: .module) }

    public static var reservationAlreadyReserved: String { String(localized: "reservation_already_reserved", bundle: .module) }

    public static var reservationCancel: String { String(localized: "reservation_cancel", bundle: .module) }

    public static var reservationCancelAction: String { String(localized: "reservation_cancel_action", bundle: .module) }

    public static func reservationCancelConfirmation(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("reservation_cancel_confirmation", bundle: .module, comment: ""), value1)
    }

    public static var reservationCancelSeries: String { String(localized: "reservation_cancel_series", bundle: .module) }

    public static var reservationCancelSeriesHelp: String { String(localized: "reservation_cancel_series_help", bundle: .module) }

    public static var reservationEmpty: String { String(localized: "reservation_empty", bundle: .module) }

    public static var reservationLoadFailed: String { String(localized: "reservation_load_failed", bundle: .module) }

    public static var reservationOnce: String { String(localized: "reservation_once", bundle: .module) }

    public static var reservationRecording: String { String(localized: "reservation_recording", bundle: .module) }

    public static var reservationReserved: String { String(localized: "reservation_reserved", bundle: .module) }

    public static var reservationScheduled: String { String(localized: "reservation_scheduled", bundle: .module) }

    public static var reservationSeries: String { String(localized: "reservation_series", bundle: .module) }

    public static var reservationTitle: String { String(localized: "reservation_title", bundle: .module) }

    public static var reservationWaitingHelp: String { String(localized: "reservation_waiting_help", bundle: .module) }

    public static var reservationWaitingSeries: String { String(localized: "reservation_waiting_series", bundle: .module) }

    public static var searchConditions: String { String(localized: "search_conditions", bundle: .module) }

    public static var searchConditionsAndroid: String { String(localized: "search_conditions_android", bundle: .module) }

    public static var searchHelp: String { String(localized: "search_help", bundle: .module) }

    public static func searchLiteral(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("search_literal", bundle: .module, comment: ""), value1)
    }

    public static var searchLoading: String { String(localized: "search_loading", bundle: .module) }

    public static func searchNoResults(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("search_no_results", bundle: .module, comment: ""), value1)
    }

    public static var searchNoResultsHelp: String { String(localized: "search_no_results_help", bundle: .module) }

    public static var searchPlaceholder: String { String(localized: "search_placeholder", bundle: .module) }

    public static func searchRemoveCondition(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("search_remove_condition", bundle: .module, comment: ""), value1)
    }

    public static var searchTitle: String { String(localized: "search_title", bundle: .module) }

    public static var serverHostPlaceholder: String { String(localized: "server_host_placeholder", bundle: .module) }

    public static var serverPort: String { String(localized: "server_port", bundle: .module) }

    public static func serverPortHelp(_ value1: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("server_port_help", bundle: .module, comment: ""), Int64(value1))
    }

    public static var serverPortInvalid: String { String(localized: "server_port_invalid", bundle: .module) }

    public static func serverSearch(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("server_search", bundle: .module, comment: ""), value1)
    }

    public static func serverSearching(_ value1: String) -> String {
        String.localizedStringWithFormat(NSLocalizedString("server_searching", bundle: .module, comment: ""), value1)
    }

    public static var settingsGuideHelp: String { String(localized: "settings_guide_help", bundle: .module) }

    public static var settingsGuideIntegration: String { String(localized: "settings_guide_integration", bundle: .module) }

    public static var settingsGuideRequired: String { String(localized: "settings_guide_required", bundle: .module) }

    public static var settingsGuideTitle: String { String(localized: "settings_guide_title", bundle: .module) }

    public static var settingsRecordingServers: String { String(localized: "settings_recording_servers", bundle: .module) }

    public static var settingsServersHelp: String { String(localized: "settings_servers_help", bundle: .module) }

    public static var settingsStreamHelpAndroid: String { String(localized: "settings_stream_help_android", bundle: .module) }

    public static var settingsStreamHelpIos: String { String(localized: "settings_stream_help_ios", bundle: .module) }

    public static var settingsStreamIntegration: String { String(localized: "settings_stream_integration", bundle: .module) }

    public static var settingsStreamTitle: String { String(localized: "settings_stream_title", bundle: .module) }

    public static var settingsTitle: String { String(localized: "settings_title", bundle: .module) }

    public static var settingsUnlink: String { String(localized: "settings_unlink", bundle: .module) }

    public static var tabChannels: String { String(localized: "tab_channels", bundle: .module) }

    public static var tabGuide: String { String(localized: "tab_guide", bundle: .module) }

    public static var tabRemote: String { String(localized: "tab_remote", bundle: .module) }

    public static var tabReservations: String { String(localized: "tab_reservations", bundle: .module) }

    public static var tvCredentials: String { String(localized: "tv_credentials", bundle: .module) }

    public static var tvHostPlaceholder: String { String(localized: "tv_host_placeholder", bundle: .module) }

    public static var tvLegacyHelp: String { String(localized: "tv_legacy_help", bundle: .module) }

    public static var tvNetworkHelpAndroid: String { String(localized: "tv_network_help_android", bundle: .module) }

    public static var tvNetworkHelpIos: String { String(localized: "tv_network_help_ios", bundle: .module) }

    public static var tvPassword: String { String(localized: "tv_password", bundle: .module) }

    public static var tvPinInputHelp: String { String(localized: "tv_pin_input_help", bundle: .module) }

    public static var tvPinPlaceholder: String { String(localized: "tv_pin_placeholder", bundle: .module) }

    public static var tvPinRegistration: String { String(localized: "tv_pin_registration", bundle: .module) }

    public static var tvPinStartHelp: String { String(localized: "tv_pin_start_help", bundle: .module) }

    public static var tvRegisterAgain: String { String(localized: "tv_register_again", bundle: .module) }

    public static var tvSearch: String { String(localized: "tv_search", bundle: .module) }

    public static var tvSearching: String { String(localized: "tv_searching", bundle: .module) }

    public static var tvShowPin: String { String(localized: "tv_show_pin", bundle: .module) }

    public static var tvTest: String { String(localized: "tv_test", bundle: .module) }

    public static var tvTitle: String { String(localized: "tv_title", bundle: .module) }

    public static var tvUsername: String { String(localized: "tv_username", bundle: .module) }
}
