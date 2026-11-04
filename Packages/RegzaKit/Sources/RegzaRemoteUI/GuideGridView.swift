#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 新聞のテレビ欄のような番組表。横に局、縦に時刻を並べる
struct GuideGridView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.showRemote) private var showRemote
    @Environment(\.showSettings) private var showSettings
    @State private var hasLoaded = false
    @State private var selection: GuideSelection?
    /// 表の左上がスクロールでどれだけずれたか (固定する局名の行と時刻の列を合わせる)
    @State private var scrollOrigin = ScrollOrigin()

    /// 今の時刻の正時から 24 時間分
    static let hours = 24
    static let columnWidth: CGFloat = 120
    static let pointsPerMinute: CGFloat = 2.4
    static let timeColumnWidth: CGFloat = 28
    static let headerHeight: CGFloat = 36

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("番組表")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selection) { selection in
                    ProgramDetailView(program: selection.program, channel: selection.channel) {
                        self.selection = nil
                        showRemote()
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasGuide {
            // Mirakurun がなくてもタブは消さず (HIG)、何ができるかと設定のしかたを案内する
            ContentUnavailableView {
                Label("番組表を使うには", systemImage: "calendar")
            } description: {
                Text("""
                    録画サーバー Mirakurun を使っていると、番組名つきの番組表や、番組表からの録画予約・連ドラ予約が使えます。
                    設定画面の「録画サーバーとの連携」で Mirakurun のアドレスを設定してください。
                    """)
            } actions: {
                Button("設定を開く") { showSettings() }
                    .buttonStyle(.borderedProminent)
            }
        } else if !hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if columns.isEmpty {
            ContentUnavailableView {
                Label("番組表を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("テレビと Mirakurun につながっているか確認してください。")
            } actions: {
                Button("もう一度試す") { Task { await load() } }
            }
        } else {
            VStack(spacing: 0) {
                if bands.count > 1 {
                    BandPicker(bands: bands)
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    grid(now: context.date)
                }
            }
        }
    }

    private func grid(now: Date) -> some View {
        let window = Self.window(now: now)
        let height = CGFloat(Self.hours * 60) * Self.pointsPerMinute
        // 縦横を 1 つのスクロールにまとめ、局名の行と時刻の列はスクロール量に合わせてずらして重ねる
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns, id: \.channel) { column in
                    ProgramColumn(programs: column.programs, window: window) { program in
                        selection = GuideSelection(program: program, channel: column.channel)
                    }
                }
            }
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topLeading) {
                // 今の時刻の線
                Rectangle()
                    .fill(.red)
                    .frame(height: 1)
                    .offset(y: Self.offset(of: now, in: window))
                    .allowsHitTesting(false)
            }
            .padding(.leading, Self.timeColumnWidth)
            .padding(.top, Self.headerHeight)
        }
        .onScrollGeometryChange(for: CGPoint.self) { geometry in
            // 余白 (ナビゲーションバーの下など) を除いた、中身の左上の位置
            CGPoint(
                x: -(geometry.contentOffset.x + geometry.contentInsets.leading),
                y: -(geometry.contentOffset.y + geometry.contentInsets.top)
            )
        } action: { _, value in
            scrollOrigin.value = value
        }
        .overlay(alignment: .topLeading) {
            PinnedTimeColumn(window: window, height: height, origin: scrollOrigin)
                // 表示している範囲で切る (列そのものは 24 時間分の高さがある)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                // 重ねた行と列の上からでもスクロールできるようにする
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            PinnedHeader(channels: columns.map(\.channel), origin: scrollOrigin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.headerHeight)
                .clipped()
                .background(.bar)
                .overlay(alignment: .bottom) { GridLine(axis: .horizontal) }
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            // 左上の角は局名の行と時刻の列が重なるので隠す
            Rectangle()
                .fill(.bar)
                .frame(width: Self.timeColumnWidth, height: Self.headerHeight)
                .allowsHitTesting(false)
        }
    }

    // MARK: - データ

    private struct Column {
        var channel: RegzaChannel
        var programs: [MirakurunProgram]
    }

    /// 選んだ放送の局。サブチャンネル (同じリモコン番号の局) は代表のものだけにする
    private var columns: [Column] {
        var seenRemoteNumbers: Set<Int> = []
        let band = model.band(among: bands)
        let candidates = model.channels.filter { $0.band == band && model.guidePrograms[$0.code] != nil }
        // 代表チャンネルを先に見て、同じリモコン番号のサブチャンネルを除く
        let representatives = Set(candidates.filter(\.isRepresentative).map(\.remoteNumber))
        return candidates.compactMap { channel in
            if channel.remoteNumber > 0 {
                if representatives.contains(channel.remoteNumber), !channel.isRepresentative { return nil }
                guard seenRemoteNumbers.insert(channel.remoteNumber).inserted else { return nil }
            }
            return Column(channel: channel, programs: model.guidePrograms[channel.code] ?? [])
        }
    }

    private var bands: [RegzaChannel.Band] {
        RegzaChannel.Band.allCases.filter { band in
            model.channels.contains { $0.band == band && model.guidePrograms[$0.code] != nil }
        }
    }

    private func load() async {
        defer { hasLoaded = true }
        try? await model.loadChannels()
        await model.loadGuidePrograms()
        // 予約した番組に印を付けるため
        try? await model.loadReservations()
        #if DEBUG
        // 開発用: 起動引数 -SampleDetail YES で、放送中の番組の詳細を開いておく
        if SampleData.isEnabled, UserDefaults.standard.bool(forKey: "SampleDetail"),
           let column = columns.first, let program = column.programs.first(where: { $0.isOnAir() }) {
            selection = GuideSelection(program: program, channel: column.channel)
        }
        #endif
    }

    // MARK: - 位置の計算

    static func window(now: Date) -> ClosedRange<Date> {
        let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        return start...start.addingTimeInterval(TimeInterval(hours * 3600))
    }

    static func offset(of date: Date, in window: ClosedRange<Date>) -> CGFloat {
        let clamped = min(max(date, window.lowerBound), window.upperBound)
        return CGFloat(clamped.timeIntervalSince(window.lowerBound) / 60) * pointsPerMinute
    }
}

/// 枠の境目の線。`Divider` は親の並べ方で縦横が変わり、重ねて置くと枠の真ん中に縦線が出るので使わない
private struct GridLine: View {
    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: axis == .vertical ? 0.5 : nil, height: axis == .horizontal ? 0.5 : nil)
    }
}

/// スクロール量。表の本体はこれを読まないので、スクロールしても描き直すのは固定した行と列だけになる
@MainActor @Observable
private final class ScrollOrigin {
    var value: CGPoint = .zero
}

/// 左に固定する時刻の列。縦のスクロールにだけ合わせて動かす
private struct PinnedTimeColumn: View {
    let window: ClosedRange<Date>
    let height: CGFloat
    let origin: ScrollOrigin

    var body: some View {
        TimeColumn(window: window)
            .frame(height: height, alignment: .top)
            .offset(y: GuideGridView.headerHeight + origin.value.y)
    }
}

/// 上に固定する局名の行。横のスクロールにだけ合わせて動かす
private struct PinnedHeader: View {
    let channels: [RegzaChannel]
    let origin: ScrollOrigin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(channels, id: \.self) { channel in
                Text(channel.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .frame(width: GuideGridView.columnWidth, height: GuideGridView.headerHeight)
                    .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
            }
        }
        .offset(x: GuideGridView.timeColumnWidth + origin.value.x)
    }
}

private struct GuideSelection: Hashable {
    var program: MirakurunProgram
    var channel: RegzaChannel
}

/// 左端の時刻 (正時ごと)
private struct TimeColumn: View {
    let window: ClosedRange<Date>

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(0..<GuideGridView.hours, id: \.self) { hour in
                let date = window.lowerBound.addingTimeInterval(TimeInterval(hour * 3600))
                Text("\(Calendar.current.component(.hour, from: date))")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: GuideGridView.timeColumnWidth, height: 60 * GuideGridView.pointsPerMinute, alignment: .top)
                    .padding(.top, 2)
                    .overlay(alignment: .top) { GridLine(axis: .horizontal) }
                    .offset(y: GuideGridView.offset(of: date, in: window))
            }
        }
        .frame(width: GuideGridView.timeColumnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        // 表の上に重ねるので、下の番組が透けないようにする
        .background(.fill.quinary)
        .background(.background)
        .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
    }
}

/// 1 局分の番組の枠
private struct ProgramColumn: View {
    let programs: [MirakurunProgram]
    let window: ClosedRange<Date>
    var onSelect: (MirakurunProgram) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(programs.filter { $0.end > window.lowerBound && $0.start < window.upperBound }) { program in
                let top = GuideGridView.offset(of: program.start, in: window)
                let bottom = GuideGridView.offset(of: program.end, in: window)
                Button {
                    onSelect(program)
                } label: {
                    ProgramCell(program: program)
                        .frame(width: GuideGridView.columnWidth, height: max(1, bottom - top), alignment: .topLeading)
                        .clipped()
                }
                .buttonStyle(.plain)
                .offset(y: top)
            }
        }
        .frame(width: GuideGridView.columnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
    }
}

private struct ProgramCell: View {
    @Environment(RemoteViewModel.self) private var model
    let program: MirakurunProgram

    var body: some View {
        let isOnAir = program.isOnAir()
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(program.start, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit().weight(isOnAir ? .semibold : .regular))
                    .foregroundStyle(isOnAir ? AppTheme.accent : .secondary)
                if model.isReserved(program) {
                    Image(systemName: "record.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .accessibilityLabel("録画予約済み")
                }
            }
            Text(program.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 枠は無地にし、ジャンルは左端の細い線、放送中は緑で示す
        .background {
            Surface.button
                .overlay { if isOnAir { AppTheme.accent.opacity(0.14) } }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(genreColor.opacity(0.8)).frame(width: 3)
        }
        .overlay(alignment: .top) { GridLine(axis: .horizontal) }
    }

    /// ジャンル (ARIB の大分類) ごとの色
    private var genreColor: Color {
        switch program.genres.first {
        case 0: .blue
        case 1: .green
        case 2: .teal
        case 3: .pink
        case 4: .purple
        case 5: .orange
        case 6: .red
        case 7: .yellow
        case 8: .brown
        case 9: .indigo
        case 10: .mint
        default: .gray
        }
    }
}
#endif
