#if os(iOS)
import RegzaPresentation
import RegzaDesign
import SwiftUI

/// 1 チャンネルの番組表 (Mirakurun)。放送中の番組から日ごとに並べる
struct ChannelProgramsView: View {
    @State private var viewModel: ProgramListViewModel

    init(viewModel: ProgramListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let state = viewModel.state
        content(state)
            .navigationTitle(state.channelName)
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.send(.appear) }
            .refreshable {
                viewModel.send(.reload)
                await waitWhileBusy(viewModel)
            }
    }

    @ViewBuilder
    private func content(_ state: ProgramListViewModel.State) -> some View {
        if let days = state.days {
            if days.isEmpty {
                ContentUnavailableView("番組表がありません", systemImage: "calendar",
                                       description: Text("Mirakurun がこのチャンネルの番組表を持っていません。"))
            } else {
                List {
                    ForEach(days) { group in
                        Section {
                            ForEach(group.programs) { program in
                                NavigationLink(value: AppViewModel.Route.programDetail(programID: program.id, channelCode: state.channelCode)) {
                                    ProgramRow(program: program)
                                }
                            }
                        } header: {
                            Text(group.label)
                        }
                    }
                }
            }
        } else if let message = state.loadErrorMessage {
            ContentUnavailableView {
                Label("番組表を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("もう一度試す") { viewModel.send(.reload) }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 録画予約した番組に付ける印
struct ReservedBadge: View {
    var compact = false

    var body: some View {
        Label(compact ? "予約" : "録画予約済み", systemImage: "record.circle.fill")
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
            .labelStyle(.titleAndIcon)
    }
}

private struct ProgramRow: View {
    let program: ProgramItem
    private var isReserved: Bool { program.isReserved }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(program.startText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(program.isOnAir ? AppTheme.accent : .secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if isReserved {
                        ReservedBadge(compact: true)
                    }
                    if program.isOnAir {
                        Text("放送中").foregroundStyle(AppTheme.accent)
                    }
                    if let genre = program.genreName {
                        Text(genre)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgramDetailView: View {
    @State private var viewModel: ProgramDetailViewModel
    @Environment(AppViewModel.self) private var app

    init(viewModel: ProgramDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var state: ProgramDetailViewModel.State { viewModel.state }
    private var program: ProgramItem { state.program }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.group) {
                header
                actions
                if let message = state.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                details
            }
            .padding(Design.outer)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Surface.background)
        .navigationTitle("番組の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: state.reserveCount)
        .animation(.default, value: state.isReserved)
        .task { viewModel.send(.appear) }
    }

    /// 局名・番組名・時刻。番組名をいちばん大きくする
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(state.channelName)
                if program.isOnAir {
                    Text("· 放送中")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)

            Text(program.name)
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
        VStack(spacing: Design.item) {
            HStack(spacing: Design.item) {
                if state.canTune {
                    Button {
                        viewModel.send(.tune(startOver: false))
                    } label: {
                        actionLabel("切り替えて見る", systemImage: "play.fill", isBusy: state.isTuning)
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
                    app.send(.play(channelCode: state.channelCode))
                } label: {
                    actionLabel("アプリで見る", systemImage: "play.tv", isBusy: false)
                }
                .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .primary))
            }
            if state.canStartOver {
                Button {
                    viewModel.send(.tune(startOver: true))
                } label: {
                    actionLabel("最初から見る", systemImage: "backward.end.alt", isBusy: false)
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
                    Label(isSeries ? "連ドラ予約を取り消す" : "予約を取り消す", systemImage: "xmark.circle")
                }
            } label: {
                actionLabel("予約済み", systemImage: "checkmark", isBusy: state.reserving != nil)
            }
            .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .red))
            .disabled(state.reserving != nil)
        } else {
            Menu {
                Button {
                    viewModel.send(.reserve(series: false))
                } label: {
                    Label("この回だけ録画", systemImage: "record.circle")
                }
                Button {
                    viewModel.send(.reserve(series: true))
                } label: {
                    Label("連ドラ予約（毎回録画）", systemImage: "repeat")
                }
            } label: {
                actionLabel("録画予約", systemImage: "record.circle", isBusy: state.reserving != nil)
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
        .frame(maxWidth: .infinity, minHeight: Design.regularHeight)
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
            .background(color, in: RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
#endif
