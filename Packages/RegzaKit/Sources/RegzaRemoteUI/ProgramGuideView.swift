#if os(iOS)
import RegzaCore
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

private struct ProgramRow: View {
    let program: MirakurunProgram

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(program.start, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(program.isOnAir() ? Color.orange : .secondary)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if program.isOnAir() {
                        Text("放送中").foregroundStyle(.orange)
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

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
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
