// Localizable.xcstringsから生成。直接編集せずmise run generate-localizationsを実行してください。
package com.example.regzaremote.localization

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import com.example.regzaremote.R

object AppStrings {
    val activityDisabledHelp: String
        @Composable get() = stringResource(R.string.activity_disabled_help)

    val activityHelp: String
        @Composable get() = stringResource(R.string.activity_help)

    val activityTitle: String
        @Composable get() = stringResource(R.string.activity_title)

    val appName: String
        @Composable get() = stringResource(R.string.app_name)

    val appearanceDark: String
        @Composable get() = stringResource(R.string.appearance_dark)

    val appearanceLight: String
        @Composable get() = stringResource(R.string.appearance_light)

    val appearanceSystem: String
        @Composable get() = stringResource(R.string.appearance_system)

    val appearanceTitle: String
        @Composable get() = stringResource(R.string.appearance_title)

    val broadcastTitle: String
        @Composable get() = stringResource(R.string.broadcast_title)

    @Composable
    fun channelGuideTitle(value1: String): String = stringResource(R.string.channel_guide_title, value1)

    val channelListTitle: String
        @Composable get() = stringResource(R.string.channel_list_title)

    val channelLoadFailed: String
        @Composable get() = stringResource(R.string.channel_load_failed)

    val channelMissing: String
        @Composable get() = stringResource(R.string.channel_missing)

    @Composable
    fun channelOnAir(value1: String): String = stringResource(R.string.channel_on_air, value1)

    val channelSwitch: String
        @Composable get() = stringResource(R.string.channel_switch)

    val channelSwitchWatch: String
        @Composable get() = stringResource(R.string.channel_switch_watch)

    val channelWatching: String
        @Composable get() = stringResource(R.string.channel_watching)

    val commonBack: String
        @Composable get() = stringResource(R.string.common_back)

    val commonCancel: String
        @Composable get() = stringResource(R.string.common_cancel)

    val commonClose: String
        @Composable get() = stringResource(R.string.common_close)

    val commonConfigure: String
        @Composable get() = stringResource(R.string.common_configure)

    val commonDisplay: String
        @Composable get() = stringResource(R.string.common_display)

    val commonOpenSettings: String
        @Composable get() = stringResource(R.string.common_open_settings)

    val commonRegister: String
        @Composable get() = stringResource(R.string.common_register)

    val commonReload: String
        @Composable get() = stringResource(R.string.common_reload)

    val commonRetry: String
        @Composable get() = stringResource(R.string.common_retry)

    val commonSave: String
        @Composable get() = stringResource(R.string.common_save)

    val commonSelected: String
        @Composable get() = stringResource(R.string.common_selected)

    val guideChannelEmpty: String
        @Composable get() = stringResource(R.string.guide_channel_empty)

    val guideConnectionHelp: String
        @Composable get() = stringResource(R.string.guide_connection_help)

    val guideEmpty: String
        @Composable get() = stringResource(R.string.guide_empty)

    val guideLoadFailed: String
        @Composable get() = stringResource(R.string.guide_load_failed)

    val guideSetupHelp: String
        @Composable get() = stringResource(R.string.guide_setup_help)

    val guideSetupTitle: String
        @Composable get() = stringResource(R.string.guide_setup_title)

    val liveBadge: String
        @Composable get() = stringResource(R.string.live_badge)

    val liveRetry: String
        @Composable get() = stringResource(R.string.live_retry)

    val liveTitle: String
        @Composable get() = stringResource(R.string.live_title)

    val networkPermissionAllow: String
        @Composable get() = stringResource(R.string.network_permission_allow)

    val networkPermissionHelp: String
        @Composable get() = stringResource(R.string.network_permission_help)

    val networkPermissionTitle: String
        @Composable get() = stringResource(R.string.network_permission_title)

    val playerFromStart: String
        @Composable get() = stringResource(R.string.player_from_start)

    val playerNowPlaying: String
        @Composable get() = stringResource(R.string.player_now_playing)

    val playerPlay: String
        @Composable get() = stringResource(R.string.player_play)

    val playerProgramFromStart: String
        @Composable get() = stringResource(R.string.player_program_from_start)

    val playerWatch: String
        @Composable get() = stringResource(R.string.player_watch)

    val programChannelGuide: String
        @Composable get() = stringResource(R.string.program_channel_guide)

    val programDescription: String
        @Composable get() = stringResource(R.string.program_description)

    val programDetails: String
        @Composable get() = stringResource(R.string.program_details)

    val programMissing: String
        @Composable get() = stringResource(R.string.program_missing)

    val programOnAir: String
        @Composable get() = stringResource(R.string.program_on_air)

    @Composable
    fun programOnAirTime(value1: String): String = stringResource(R.string.program_on_air_time, value1)

    val programOpenDetails: String
        @Composable get() = stringResource(R.string.program_open_details)

    @Composable
    fun programTimeRange(value1: String, value2: String): String = stringResource(R.string.program_time_range, value1, value2)

    @Composable
    fun recordingChannel(value1: String): String = stringResource(R.string.recording_channel, value1)

    val recordingTitle: String
        @Composable get() = stringResource(R.string.recording_title)

    val remoteConnecting: String
        @Composable get() = stringResource(R.string.remote_connecting)

    val remoteConnectionFailed: String
        @Composable get() = stringResource(R.string.remote_connection_failed)

    val remoteEnter: String
        @Composable get() = stringResource(R.string.remote_enter)

    val remoteMore: String
        @Composable get() = stringResource(R.string.remote_more)

    val remotePlayback: String
        @Composable get() = stringResource(R.string.remote_playback)

    val remotePowerOn: String
        @Composable get() = stringResource(R.string.remote_power_on)

    val remoteSearching: String
        @Composable get() = stringResource(R.string.remote_searching)

    val remoteSetupHelp: String
        @Composable get() = stringResource(R.string.remote_setup_help)

    val remoteTvGuide: String
        @Composable get() = stringResource(R.string.remote_tv_guide)

    val remoteUnconfigured: String
        @Composable get() = stringResource(R.string.remote_unconfigured)

    val remoteVolume: String
        @Composable get() = stringResource(R.string.remote_volume)

    val reservationAlreadyReserved: String
        @Composable get() = stringResource(R.string.reservation_already_reserved)

    val reservationCancel: String
        @Composable get() = stringResource(R.string.reservation_cancel)

    val reservationCancelAction: String
        @Composable get() = stringResource(R.string.reservation_cancel_action)

    @Composable
    fun reservationCancelConfirmation(value1: String): String = stringResource(R.string.reservation_cancel_confirmation, value1)

    val reservationCancelSeries: String
        @Composable get() = stringResource(R.string.reservation_cancel_series)

    val reservationCancelSeriesHelp: String
        @Composable get() = stringResource(R.string.reservation_cancel_series_help)

    val reservationEmpty: String
        @Composable get() = stringResource(R.string.reservation_empty)

    val reservationLoadFailed: String
        @Composable get() = stringResource(R.string.reservation_load_failed)

    val reservationOnce: String
        @Composable get() = stringResource(R.string.reservation_once)

    val reservationRecording: String
        @Composable get() = stringResource(R.string.reservation_recording)

    val reservationReserved: String
        @Composable get() = stringResource(R.string.reservation_reserved)

    val reservationScheduled: String
        @Composable get() = stringResource(R.string.reservation_scheduled)

    val reservationSeries: String
        @Composable get() = stringResource(R.string.reservation_series)

    val reservationTitle: String
        @Composable get() = stringResource(R.string.reservation_title)

    val reservationWaitingHelp: String
        @Composable get() = stringResource(R.string.reservation_waiting_help)

    val reservationWaitingSeries: String
        @Composable get() = stringResource(R.string.reservation_waiting_series)

    val searchConditions: String
        @Composable get() = stringResource(R.string.search_conditions)

    val searchConditionsAndroid: String
        @Composable get() = stringResource(R.string.search_conditions_android)

    val searchHelp: String
        @Composable get() = stringResource(R.string.search_help)

    @Composable
    fun searchLiteral(value1: String): String = stringResource(R.string.search_literal, value1)

    val searchLoading: String
        @Composable get() = stringResource(R.string.search_loading)

    @Composable
    fun searchNoResults(value1: String): String = stringResource(R.string.search_no_results, value1)

    val searchNoResultsHelp: String
        @Composable get() = stringResource(R.string.search_no_results_help)

    val searchPlaceholder: String
        @Composable get() = stringResource(R.string.search_placeholder)

    @Composable
    fun searchRemoveCondition(value1: String): String = stringResource(R.string.search_remove_condition, value1)

    val searchTitle: String
        @Composable get() = stringResource(R.string.search_title)

    val serverHostPlaceholder: String
        @Composable get() = stringResource(R.string.server_host_placeholder)

    val serverPort: String
        @Composable get() = stringResource(R.string.server_port)

    @Composable
    fun serverPortHelp(value1: Int): String = stringResource(R.string.server_port_help, value1)

    val serverPortInvalid: String
        @Composable get() = stringResource(R.string.server_port_invalid)

    @Composable
    fun serverSearch(value1: String): String = stringResource(R.string.server_search, value1)

    @Composable
    fun serverSearching(value1: String): String = stringResource(R.string.server_searching, value1)

    val settingsGuideHelp: String
        @Composable get() = stringResource(R.string.settings_guide_help)

    val settingsGuideIntegration: String
        @Composable get() = stringResource(R.string.settings_guide_integration)

    val settingsGuideRequired: String
        @Composable get() = stringResource(R.string.settings_guide_required)

    val settingsGuideTitle: String
        @Composable get() = stringResource(R.string.settings_guide_title)

    val settingsRecordingServers: String
        @Composable get() = stringResource(R.string.settings_recording_servers)

    val settingsServersHelp: String
        @Composable get() = stringResource(R.string.settings_servers_help)

    val settingsStreamHelpAndroid: String
        @Composable get() = stringResource(R.string.settings_stream_help_android)

    val settingsStreamHelpIos: String
        @Composable get() = stringResource(R.string.settings_stream_help_ios)

    val settingsStreamIntegration: String
        @Composable get() = stringResource(R.string.settings_stream_integration)

    val settingsStreamTitle: String
        @Composable get() = stringResource(R.string.settings_stream_title)

    val settingsTitle: String
        @Composable get() = stringResource(R.string.settings_title)

    val settingsUnlink: String
        @Composable get() = stringResource(R.string.settings_unlink)

    val tabChannels: String
        @Composable get() = stringResource(R.string.tab_channels)

    val tabGuide: String
        @Composable get() = stringResource(R.string.tab_guide)

    val tabRemote: String
        @Composable get() = stringResource(R.string.tab_remote)

    val tabReservations: String
        @Composable get() = stringResource(R.string.tab_reservations)

    val tvCredentials: String
        @Composable get() = stringResource(R.string.tv_credentials)

    val tvHostPlaceholder: String
        @Composable get() = stringResource(R.string.tv_host_placeholder)

    val tvLegacyHelp: String
        @Composable get() = stringResource(R.string.tv_legacy_help)

    val tvNetworkHelpAndroid: String
        @Composable get() = stringResource(R.string.tv_network_help_android)

    val tvNetworkHelpIos: String
        @Composable get() = stringResource(R.string.tv_network_help_ios)

    val tvPassword: String
        @Composable get() = stringResource(R.string.tv_password)

    val tvPinInputHelp: String
        @Composable get() = stringResource(R.string.tv_pin_input_help)

    val tvPinPlaceholder: String
        @Composable get() = stringResource(R.string.tv_pin_placeholder)

    val tvPinRegistration: String
        @Composable get() = stringResource(R.string.tv_pin_registration)

    val tvPinStartHelp: String
        @Composable get() = stringResource(R.string.tv_pin_start_help)

    val tvRegisterAgain: String
        @Composable get() = stringResource(R.string.tv_register_again)

    val tvSearch: String
        @Composable get() = stringResource(R.string.tv_search)

    val tvSearching: String
        @Composable get() = stringResource(R.string.tv_searching)

    val tvShowPin: String
        @Composable get() = stringResource(R.string.tv_show_pin)

    val tvTest: String
        @Composable get() = stringResource(R.string.tv_test)

    val tvTitle: String
        @Composable get() = stringResource(R.string.tv_title)

    val tvUsername: String
        @Composable get() = stringResource(R.string.tv_username)
}
