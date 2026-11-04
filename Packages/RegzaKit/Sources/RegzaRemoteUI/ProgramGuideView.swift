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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if model.isReserved(program) {
                        ReservedBadge()
                    }
                    Text(program.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(program.start, format: .dateTime.month().day().weekday().hour().minute())
                        Text("〜")
                        Text(program.end, format: .dateTime.hour().minute())
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(channel.name)
                        if let genre = program.genreName { Text("· \(genre)") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.subheadline)
                }
            }
            ForEach(program.extended, id: \.title) { item in
                Section(item.title) {
                    Text(item.text)
                        .font(.subheadline)
                }
            }
            if program.end > Date() {
                Section {
                    if let reservation = model.reservation(for: program) {
                        Label(reservation.isSeries ? "連ドラ予約しました" : "録画予約しました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.body.weight(.semibold))
                        if reservation.isSeries, let repeatLabel = reservation.repeatLabel {
                            Text("\(repeatLabel)、この番組の続きを録画します。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button(role: .destructive) {
                            Task { await cancel(reservation) }
                        } label: {
                            HStack {
                                Label("予約を取り消す", systemImage: "xmark.circle")
                                Spacer()
                                if isReserving == .cancel { ProgressView() }
                            }
                        }
                        .disabled(isReserving != nil)
                    } else {
                        Button {
                            Task { await reserve(series: false) }
                        } label: {
                            HStack {
                                Label("この回を録画予約", systemImage: "record.circle")
                                Spacer()
                                if isReserving == .single { ProgressView() }
                            }
                        }
                        .tint(.red)
                        .disabled(isReserving != nil)
                        Button {
                            Task { await reserve(series: true) }
                        } label: {
                            HStack {
                                Label("連ドラ予約（毎回録画）", systemImage: "repeat.circle")
                                Spacer()
                                if isReserving == .series { ProgressView() }
                            }
                        }
                        .tint(.red)
                        .disabled(isReserving != nil)
                    }
                    if let reserveMessage {
                        Text(reserveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if !model.isReserved(program) {
                        Text("連ドラ予約では、毎週・平日などの繰り返しをテレビが番組から決めます。保存先などはテレビの設定どおりです。")
                    }
                }
            }
            if program.isOnAir() {
                Section {
                    Button {
                        Task { await tune() }
                    } label: {
                        HStack {
                            Label("このチャンネルに切り替える", systemImage: "tv")
                            Spacer()
                            if isTuning { ProgressView() }
                        }
                    }
                    .disabled(isTuning)
                    if let tuneError {
                        Text(tuneError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("番組の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: reserveFeedback)
        .animation(.default, value: model.isReserved(program))
        .task {
            // 予約済みかを出すため
            if model.reservations.isEmpty { try? await model.loadReservations() }
        }
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

    private func tune() async {
        isTuning = true
        defer { isTuning = false }
        do {
            try await model.tune(to: channel)
            onTune()
        } catch {
            tuneError = error.localizedDescription
        }
    }
}
#endif
