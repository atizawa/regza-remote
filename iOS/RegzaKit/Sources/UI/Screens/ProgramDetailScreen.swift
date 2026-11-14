#if os(iOS)
import Localization
import Design
import RegzaPresentation
import SwiftUI

struct ProgramDetailScreen: View {
    @State private var viewModel: ProgramDetailViewModel
    @Environment(AppViewModel.self) private var appViewModel

    init(viewModel: ProgramDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var state: ProgramDetailViewModel.State { viewModel.state }
    private var program: ProgramItem { state.program }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignDimensions.spacingGroup) {
                header
                actions
                if let message = state.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                details
            }
            .padding(DesignDimensions.spacingOuter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Surface.background)
        .navigationTitle(AppStrings.programDetails)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: state.reserveCount)
        .animation(.default, value: state.isReserved)
        .task { viewModel.send(.appear) }
    }

    /// 局名・番組名・時刻。番組名をいちばん大きくする
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(program.isOnAir ? AppStrings.channelOnAir(state.channelName) : state.channelName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text(program.name)
                .accessibilityIdentifier("program.title")
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(program.timeText)
                if let genre = program.genreName { Text("· \(genre)") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if program.isOnAir {
                ProgressView(timerInterval: program.start...program.end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(AppTheme.accent)
                .padding(.top, 4)
            }

            if let reservedText = state.reservedText {
                Label(reservedText, systemImage: "record.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    /// 主な操作。見る・切り替えは緑、録画は赤で塗る
    private var actions: some View {
        VStack(spacing: DesignDimensions.spacingItem) {
            HStack(spacing: DesignDimensions.spacingItem) {
                if state.canTune {
                    Button {
                        viewModel.send(.tune(startOver: false))
                    } label: {
                        actionLabel(AppStrings.channelSwitchWatch, systemImage: "play.fill", isBusy: state.isTuning)
                    }
                    .buttonStyle(FilledActionStyle(color: AppTheme.accent))
                    .disabled(state.isTuning)
                }
                if state.canReserve {
                    reserveMenu
                }
            }
            if state.canStream {
                Button {
                    appViewModel.send(.play(channelCode: state.channelCode))
                } label: {
                    actionLabel(AppStrings.playerWatch, systemImage: "play.tv", isBusy: false)
                }
                .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .primary))
            }
            if state.canStartOver {
                Button {
                    viewModel.send(.tune(startOver: true))
                } label: {
                    actionLabel(AppStrings.playerFromStart, systemImage: "backward.end.alt", isBusy: false)
                }
                .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .primary))
                .disabled(state.isTuning)
            }
        }
    }

    /// 「録画予約」を押すと、この回だけか連ドラ予約かを選ぶ。予約済みならメニューから取り消す
    @ViewBuilder
    private var reserveMenu: some View {
        if let isSeries = state.reservationIsSeries {
            Menu {
                Button(role: .destructive) {
                    viewModel.send(.cancelReservation)
                } label: {
                    Label(isSeries ? AppStrings.reservationCancelSeries : AppStrings.reservationCancel, systemImage: "xmark.circle")
                }
            } label: {
                actionLabel(AppStrings.reservationAlreadyReserved, systemImage: "checkmark", isBusy: state.reserving != nil)
            }
            .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .red))
            .disabled(state.reserving != nil)
        } else {
            Menu {
                Button {
                    viewModel.send(.reserve(series: false))
                } label: {
                    Label(AppStrings.reservationOnce, systemImage: "record.circle")
                }
                Button {
                    viewModel.send(.reserve(series: true))
                } label: {
                    Label(AppStrings.reservationSeries, systemImage: "repeat")
                }
            } label: {
                actionLabel(AppStrings.tabReservations, systemImage: "record.circle", isBusy: state.reserving != nil)
            }
            .buttonStyle(FilledActionStyle(color: .red))
            .disabled(state.reserving != nil)
        }
    }

    private func actionLabel(_ title: String, systemImage: String, isBusy: Bool) -> some View {
        HStack(spacing: 6) {
            if isBusy {
                ProgressView()
            } else {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: DesignDimensions.buttonRegularHeight)
    }

    /// 説明と、番組内容・出演者などを見出し付きの文章で続ける
    @ViewBuilder
    private var details: some View {
        if !program.description.isEmpty {
            Text(program.description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(state.texts) { item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
/// 操作ボタンの塗り
private struct FilledActionStyle: ButtonStyle {
    let color: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(color, in: RoundedRectangle(cornerRadius: DesignDimensions.shapeCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
#endif
