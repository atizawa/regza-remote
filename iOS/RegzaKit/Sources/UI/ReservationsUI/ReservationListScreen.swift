#if os(iOS)
import Localization
import PresentationCore
import ReservationsPresentation
import SwiftUI
import UICommon
#if DEBUG
import AppPresentation
#endif

/// テレビの録画予約の一覧
package struct ReservationListScreen: View {
    @State private var viewModel: ReservationListViewModel
    /// 取り消すか確かめている予約
    @State private var canceling: ReservationItem?

    package init(viewModel: ReservationListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    package var body: some View {
        content
            .navigationTitle(AppStrings.tabReservations)
            // ほかのタブ (リモコン・番組表) と同じく小さい見出しにそろえる
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.send(.load) }
            .refreshable {
                await viewModel.sendAndWait(.load)
            }
            .confirmationDialog(
                canceling.map { AppStrings.reservationCancelConfirmation($0.title) } ?? "",
                isPresented: Binding(get: { canceling != nil }, set: { if !$0 { canceling = nil } }),
                titleVisibility: .visible,
                presenting: canceling
            ) { reservation in
                Button(reservation.isSeries ? AppStrings.reservationCancelSeries : AppStrings.reservationCancel, role: .destructive) {
                    viewModel.send(.cancel(reservation.id))
                }
            } message: { reservation in
                if reservation.isSeries {
                    Text(AppStrings.reservationCancelSeriesHelp)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        let state = viewModel.state
        if let message = state.loadErrorMessage {
            ContentUnavailableView {
                Label(AppStrings.reservationLoadFailed, systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button(AppStrings.commonRetry) { viewModel.send(.load) }
            }
        } else if !state.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.isEmpty {
            ContentUnavailableView(AppStrings.reservationEmpty, systemImage: "calendar")
        } else {
            List {
                if let cancelError = state.cancelError {
                    Text(cancelError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if !state.scheduled.isEmpty {
                    Section(AppStrings.reservationScheduled) {
                        ForEach(state.scheduled) { row($0) }
                    }
                }
                if !state.waiting.isEmpty {
                    Section {
                        ForEach(state.waiting) { row($0) }
                    } header: {
                        Text(AppStrings.reservationWaitingSeries)
                    } footer: {
                        Text(AppStrings.reservationWaitingHelp)
                    }
                }
            }
        }
    }

    private func row(_ item: ReservationItem) -> some View {
        rowContent(item)
            .swipeActions {
                Button(AppStrings.reservationCancelAction, role: .destructive) { canceling = item }
            }
    }

    private func rowContent(_ item: ReservationItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .lineLimit(2)
                .foregroundStyle(item.isScheduled ? .primary : .secondary)
            HStack(spacing: 6) {
                if item.isRecording {
                    Label(AppStrings.reservationRecording, systemImage: "record.circle")
                        .foregroundStyle(.red)
                }
                Text(item.timeText)
                if let repeatLabel = item.repeatLabel {
                    Text(repeatLabel)
                        .padding(.horizontal, 6)
                        .background(.fill.tertiary, in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let channelName = item.channelName {
                Text(channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
#Preview("録画予約") {
    FakePreview { app in
        NavigationStack { ReservationListScreen(viewModel: app.reservationListViewModel) }
    }
}
#endif
#endif
