#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 1 チャンネルの番組表 (Mirakurun)。放送中の番組から日ごとに並べる
struct ChannelProgramsView: View {
    @Environment(RemoteViewModel.self) private var model
    let channel: RegzaChannel
    /// 番組の詳細からチャンネルを切り替えたとき
    var onTune: () -> Void

    @State private var programs: [MirakurunProgram]?
    @State private var loadError: RegzaError?

    var body: some View {
        content
            .navigationTitle(channel.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MirakurunProgram.self) { program in
                ProgramDetailView(program: program, channel: channel, onTune: onTune)
            }
            .task {
                if programs == nil { await load() }
                // 予約した番組に印を付けるため
                if model.reservations.isEmpty { try? await model.loadReservations() }
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let programs {
            if programs.isEmpty {
                ContentUnavailableView("番組表がありません", systemImage: "calendar",
                                       description: Text("Mirakurun がこのチャンネルの番組表を持っていません。"))
            } else {
                List {
                    ForEach(days(programs), id: \.day) { group in
                        Section {
                            ForEach(group.programs) { program in
                                NavigationLink(value: program) {
                                    ProgramRow(program: program)
                                }
                            }
                        } header: {
                            Text(group.day, format: .dateTime.month().day().weekday())
                        }
                    }
                }
            }
        } else if let loadError {
            ContentUnavailableView {
                Label("番組表を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(loadError.localizedDescription)
            } actions: {
                Button("もう一度試す") { Task { await load() } }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func days(_ programs: [MirakurunProgram]) -> [(day: Date, programs: [MirakurunProgram])] {
        let calendar = Calendar.current
        return Dictionary(grouping: programs) { calendar.startOfDay(for: $0.start) }
            .map { (day: $0.key, programs: $0.value) }
            .sorted { $0.day < $1.day }
    }

    private func load() async {
        do {
            programs = try await model.programs(for: channel)
            loadError = nil
        } catch {
            loadError = error
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
    @Environment(RemoteViewModel.self) private var model
    let program: MirakurunProgram

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(program.start, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(program.isOnAir() ? AppTheme.accent : .secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if model.isReserved(program) {
                        ReservedBadge(compact: true)
                    }
                    if program.isOnAir() {
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
    @Environment(RemoteViewModel.self) private var model
    let program: MirakurunProgram
    let channel: RegzaChannel
    var onTune: () -> Void

    @State private var isTuning = false
    @State private var tuneError: String?
    /// 予約・取り消しの途中のもの
    @State private var isReserving: Reserving?
    @State private var reserveMessage: String?

    private enum Reserving {
        case single, series, cancel
    }
    /// 予約・取り消しが終わったときの触覚フィードバック用
    @State private var reserveFeedback = 0
    /// iPhone で見ている配信の再生画面
    @State private var isShowingPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.group) {
                header
                actions
                if let message = reserveMessage ?? tuneError {
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
        .fullScreenCover(isPresented: $isShowingPlayer) {
            if let server = model.streamServer() {
                LivePlayerView(server: server, channel: channel, programName: program.name)
            }
        }
        .sensoryFeedback(.success, trigger: reserveFeedback)
        .animation(.default, value: model.isReserved(program))
        .task {
            // 予約済みか、最初から見られるかを出すため
            if model.reservations.isEmpty { try? await model.loadReservations() }
            await model.loadTimeshiftSettings()
        }
    }

    /// 局名・番組名・時刻。番組名をいちばん大きくする
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(channel.name)
                if program.isOnAir() {
                    Text("· 放送中")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)

            Text(program.name)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(program.start, format: .dateTime.month().day().weekday().hour().minute())
                Text("〜")
                Text(program.end, format: .dateTime.hour().minute())
                Text("· \(Int(program.end.timeIntervalSince(program.start) / 60))分")
                if let genre = program.genreName { Text("· \(genre)") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if program.isOnAir() {
                ProgressView(timerInterval: program.start...program.end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(AppTheme.accent)
                .padding(.top, 4)
            }

            if let reservation = model.reservation(for: program) {
                Label(reservedText(reservation), systemImage: "record.circle.fill")
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
                if program.isOnAir() {
                    Button {
                        Task { await tune(startOver: false) }
                    } label: {
                        actionLabel("切り替えて見る", systemImage: "play.fill", isBusy: isTuning)
                    }
                    .buttonStyle(FilledActionStyle(color: AppTheme.accent))
                    .disabled(isTuning)
                }
                if program.end > Date() {
                    reserveMenu
                }
            }
            if program.isOnAir(), model.canStream {
                Button {
                    isShowingPlayer = true
                } label: {
                    actionLabel("iPhone で見る", systemImage: "iphone", isBusy: false)
                }
                .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .primary))
            }
            if program.isOnAir(), model.canStartOver(channelCode: program.channelCode, programStart: program.start) {
                Button {
                    Task { await tune(startOver: true) }
                } label: {
                    actionLabel("最初から見る", systemImage: "backward.end.alt", isBusy: false)
                }
                .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .primary))
                .disabled(isTuning)
            }
        }
    }

    /// 「録画予約」を押すと、この回だけか連ドラ予約かを選ぶ。予約済みならメニューから取り消す
    @ViewBuilder
    private var reserveMenu: some View {
        if let reservation = model.reservation(for: program) {
            Menu {
                Button(role: .destructive) {
                    Task { await cancel(reservation) }
                } label: {
                    Label(reservation.isSeries ? "連ドラ予約を取り消す" : "予約を取り消す", systemImage: "xmark.circle")
                }
            } label: {
                actionLabel("予約済み", systemImage: "checkmark", isBusy: isReserving != nil)
            }
            .buttonStyle(FilledActionStyle(color: Surface.button, foreground: .red))
            .disabled(isReserving != nil)
        } else {
            Menu {
                Button {
                    Task { await reserve(series: false) }
                } label: {
                    Label("この回だけ録画", systemImage: "record.circle")
                }
                Button {
                    Task { await reserve(series: true) }
                } label: {
                    Label("連ドラ予約（毎回録画）", systemImage: "repeat")
                }
            } label: {
                actionLabel("録画予約", systemImage: "record.circle", isBusy: isReserving != nil)
            }
            .buttonStyle(FilledActionStyle(color: .red))
            .disabled(isReserving != nil)
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
        ForEach(program.extended, id: \.title) { item in
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

    private func reservedText(_ reservation: RegzaReservation) -> String {
        guard reservation.isSeries else { return "録画予約済み" }
        return reservation.repeatLabel.map { "連ドラ予約済み（\($0)）" } ?? "連ドラ予約済み"
    }

    private func reserve(series: Bool) async {
        isReserving = series ? .series : .single
        defer { isReserving = nil }
        reserveMessage = nil
        do {
            try await model.reserve(program, series: series)
            reserveFeedback += 1
            if !model.isReserved(program) {
                // テレビの一覧にまだ反映されていない
                reserveMessage = "予約しました。テレビの予約一覧に反映されるまで少しかかることがあります。"
            }
        } catch .commandRejected(let code) {
            // 重なる予約が多い、ハードディスクがないなど
            reserveMessage = "テレビが予約を受け付けませんでした (\(code))。テレビの予約一覧や録画機器を確認してください。"
        } catch {
            reserveMessage = error.localizedDescription
        }
    }

    private func cancel(_ reservation: RegzaReservation) async {
        isReserving = .cancel
        defer { isReserving = nil }
        reserveMessage = nil
        do {
            try await model.cancel(reservation)
            reserveFeedback += 1
        } catch {
            reserveMessage = "予約を取り消せませんでした: \(error.localizedDescription)"
        }
    }

    private func tune(startOver: Bool) async {
        isTuning = true
        defer { isTuning = false }
        do {
            if startOver {
                try await model.tuneAndStartOver(channel)
            } else {
                try await model.tune(to: channel)
            }
            onTune()
        } catch {
            tuneError = error.localizedDescription
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
