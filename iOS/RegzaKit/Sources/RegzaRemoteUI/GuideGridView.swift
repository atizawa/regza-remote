#if os(iOS)
import RegzaCore
import RegzaLiveActivity
import SwiftUI

/// 新聞のテレビ欄のような番組表。横に局、縦に時刻を並べる
struct GuideGridView: View {
    @State private var viewModel: GuideGridViewModel
    @Environment(AppViewModel.self) private var app
    @Environment(\.showSettings) private var showSettings
    /// 表の左上がスクロールでどれだけずれたか (固定する局名の行と時刻の列を合わせる)
    @State private var scrollOrigin = ScrollOrigin()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: GuideGridViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// 今の時刻の正時から 24 時間分
    static let hours = GuideGridViewModel.hours
    /// 文字をこれより大きくすると 1 画面に 1 局も収まらなくなるので、番組表はここで止める
    static let maximumDynamicTypeSize = DynamicTypeSize.accessibility1

    private var metrics: GuideMetrics { GuideMetrics(dynamicTypeSize: min(dynamicTypeSize, Self.maximumDynamicTypeSize)) }

    var body: some View {
        NavigationStack(path: app.path(of: .guide)) {
            content
                .navigationTitle("番組表")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 番組表を広く使うため、検索欄は置かずにボタンから別の画面で開く
                    if viewModel.canSearch {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("番組を探す", systemImage: "magnifyingglass") { app.send(.open(.search)) }
                        }
                    }
                }
                .appRoutes()
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.guide.hasGuide {
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
        } else if !viewModel.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.columns.isEmpty {
            ContentUnavailableView {
                Label("番組表を取得できません", systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text("テレビと Mirakurun につながっているか確認してください。")
            } actions: {
                Button("もう一度試す") { Task { await load() } }
            }
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                grid(now: context.date)
            }
            .dynamicTypeSize(...Self.maximumDynamicTypeSize)
            // 上に積むと日付の横スクロールが先に見つかり、下へスクロールしてもタブバーが小さくならないので、表の上に重ねる
            .safeAreaBar(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if viewModel.bands.count > 1 {
                        BandPicker(bands: viewModel.bands)
                    }
                    DayPicker(viewModel: viewModel)
                }
            }
        }
    }

    private func grid(now: Date) -> some View {
        let window = viewModel.window(now: now)
        let columns = viewModel.columns
        let metrics = metrics
        let height = CGFloat(Self.hours * 60) * metrics.pointsPerMinute
        // 縦横を 1 つのスクロールにまとめ、局名の行と時刻の列はスクロール量に合わせてずらして重ねる
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns, id: \.channel) { column in
                    ProgramColumn(
                        channel: column.channel, programs: column.programs, window: window, metrics: metrics,
                        isReserved: viewModel.isReserved
                    ) { program in
                        app.send(.open(.programDetail(program, column.channel)))
                    }
                }
            }
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topLeading) {
                // 今の時刻の線 (今日を見ているときだけ)
                if viewModel.day == nil {
                    Rectangle()
                        .fill(.red)
                        .frame(height: 1)
                        .offset(y: metrics.offset(of: now, in: window))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, metrics.timeColumnWidth)
            .padding(.top, metrics.headerHeight)
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
            PinnedTimeColumn(window: window, height: height, metrics: metrics, origin: scrollOrigin)
                // 表示している範囲で切る (列そのものは 24 時間分の高さがある)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                // 重ねた行と列の上からでもスクロールできるようにする
                .allowsHitTesting(false)
                // 番組の枠ごとに局名と時刻を読み上げるので、重ねた行と列は読まない
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            PinnedHeader(channels: columns.map(\.channel), metrics: metrics, origin: scrollOrigin)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: metrics.headerHeight)
                .clipped()
                .background(.bar)
                .overlay(alignment: .bottom) { GridLine(axis: .horizontal) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            // 左上の角は局名の行と時刻の列が重なるので隠す
            Rectangle()
                .fill(.bar)
                .frame(width: metrics.timeColumnWidth, height: metrics.headerHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func load() async {
        await viewModel.load()
        #if DEBUG
        // 開発用: 起動引数 -SampleDetail YES で、放送中の番組の詳細を開いておく
        if SampleData.isEnabled, UserDefaults.standard.bool(forKey: "SampleDetail"),
           let column = viewModel.columns.first, let program = column.programs.first(where: { $0.isOnAir() }) {
            app.send(.setPath(.guide, [.programDetail(program, column.channel)]))
        }
        if SampleData.isEnabled, let text = UserDefaults.standard.string(forKey: "SampleSearch") {
            app.send(.setPath(.guide, [.search]))
            viewModel.search.text = text
        }
        #endif
    }
}

/// 番組表の枠の大きさ。文字の大きさの設定 (Dynamic Type) に合わせて、枠の幅と 1 分あたりの高さも同じ割合で広げる
/// (文字だけ大きくすると、枠に収まらず番組名が切れる)
struct GuideMetrics {
    /// 標準の文字の大きさ (大) を 1 とした、番組の枠の文字 (caption2) の大きさ
    let scale: CGFloat

    init(dynamicTypeSize: DynamicTypeSize) {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        scale = UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 1, compatibleWith: traits)
    }

    var columnWidth: CGFloat { 120 * scale }
    var pointsPerMinute: CGFloat { 2.4 * scale }
    var timeColumnWidth: CGFloat { 28 * scale }
    var headerHeight: CGFloat { 36 * scale }

    func offset(of date: Date, in window: ClosedRange<Date>) -> CGFloat {
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
    let metrics: GuideMetrics
    let origin: ScrollOrigin

    var body: some View {
        TimeColumn(window: window, metrics: metrics)
            .frame(height: height, alignment: .top)
            .offset(y: metrics.headerHeight + origin.value.y)
    }
}

/// 上に固定する局名の行。横のスクロールにだけ合わせて動かす
private struct PinnedHeader: View {
    let channels: [RegzaChannel]
    let metrics: GuideMetrics
    let origin: ScrollOrigin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(channels, id: \.self) { channel in
                Text(channel.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
                    .frame(width: metrics.columnWidth, height: metrics.headerHeight)
                    .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
            }
        }
        .offset(x: metrics.timeColumnWidth + origin.value.x)
    }
}

/// 左端の時刻 (正時ごと)
private struct TimeColumn: View {
    let window: ClosedRange<Date>
    let metrics: GuideMetrics

    /// 番組表と同じく、朝 4 時より前は前の日の続きとして 24〜27 時と書く
    static func hourLabel(_ date: Date) -> Int {
        BroadcastDay.hour(of: date)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(0..<GuideGridView.hours, id: \.self) { hour in
                let date = window.lowerBound.addingTimeInterval(TimeInterval(hour * 3600))
                Text("\(Self.hourLabel(date))")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: metrics.timeColumnWidth, height: 60 * metrics.pointsPerMinute, alignment: .top)
                    .padding(.top, 2)
                    .overlay(alignment: .top) { GridLine(axis: .horizontal) }
                    .offset(y: metrics.offset(of: date, in: window))
            }
        }
        .frame(width: metrics.timeColumnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        // 表の上に重ねるので、下の番組が透けないようにする
        .background(.fill.quinary)
        .background(.background)
        .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
    }
}

/// 1 局分の番組の枠
private struct ProgramColumn: View {
    let channel: RegzaChannel
    let programs: [MirakurunProgram]
    let window: ClosedRange<Date>
    let metrics: GuideMetrics
    let isReserved: (MirakurunProgram) -> Bool
    var onSelect: (MirakurunProgram) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(programs.filter { $0.end > window.lowerBound && $0.start < window.upperBound }) { program in
                let top = metrics.offset(of: program.start, in: window)
                let bottom = metrics.offset(of: program.end, in: window)
                Button {
                    onSelect(program)
                } label: {
                    ProgramCell(program: program, channelName: channel.name, isReserved: isReserved(program))
                        .frame(width: metrics.columnWidth, height: max(1, bottom - top), alignment: .topLeading)
                        .clipped()
                }
                .buttonStyle(.plain)
                .offset(y: top)
            }
        }
        // VoiceOver のローターで局ごとに移れるようにする
        .accessibilityElement(children: .contain)
        .accessibilityLabel(channel.name)
        .frame(width: metrics.columnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
    }
}

private struct ProgramCell: View {
    let program: MirakurunProgram
    let channelName: String
    let isReserved: Bool

    var body: some View {
        let isOnAir = program.isOnAir()
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(program.start, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit().weight(isOnAir ? .semibold : .regular))
                    .foregroundStyle(isOnAir ? AppTheme.accent : .secondary)
                if isReserved {
                    Image(systemName: "record.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
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
        // VoiceOver では枠を 1 つにまとめ、重ねた局名の行と時刻の列の代わりに局名と時刻も読む
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(isOnAir: isOnAir))
    }

    /// 「22時00分から22時45分、スポーツまとめ、みどりテレビ、スポーツ、録画予約済み」
    private func accessibilityText(isOnAir: Bool) -> String {
        let time = "\(program.start.formatted(date: .omitted, time: .shortened))から\(program.end.formatted(date: .omitted, time: .shortened))"
        var parts = [isOnAir ? "放送中、\(time)" : time, program.name, channelName]
        if let genre = program.genreName { parts.append(genre) }
        if isReserved { parts.append("録画予約済み") }
        return parts.joined(separator: "、")
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
/// 日付の選択。今日・明日・6(金) … を横に並べ、土曜は青、日曜は赤にする (テレビ欄と同じ)
private struct DayPicker: View {
    @Bindable var viewModel: GuideGridViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil)
                ForEach(viewModel.days, id: \.self) { chip($0) }
            }
            .padding(.horizontal, Design.outer)
            .padding(.bottom, 8)
        }
    }

    private func chip(_ day: Date?) -> some View {
        let isSelected = viewModel.day == day
        return Button {
            viewModel.day = day
        } label: {
            Text(viewModel.label(of: day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : color(day))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(.fill.tertiary), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func color(_ day: Date?) -> Color {
        switch viewModel.kind(of: day) {
        case .saturday: .blue
        case .sunday: .red
        case .weekday: .primary
        }
    }
}
#endif
