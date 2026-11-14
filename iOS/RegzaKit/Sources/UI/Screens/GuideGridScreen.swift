#if os(iOS)
import Localization
import RegzaPresentation
import Design
import SwiftUI

/// 新聞のテレビ欄のような番組表。横に局、縦に時刻を並べる
struct GuideGridScreen: View {
    @State private var viewModel: GuideGridViewModel
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.showSettings) private var showSettings
    /// 表の左上がスクロールでどれだけずれたか (固定する局名の行と時刻の列を合わせる)
    @State private var scrollOrigin = ScrollOrigin()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: GuideGridViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// 文字をこれより大きくすると 1 画面に 1 局も収まらなくなるので、番組表はここで止める
    static let maximumDynamicTypeSize = DynamicTypeSize.accessibility1

    private var metrics: GuideMetrics { GuideMetrics(dynamicTypeSize: min(dynamicTypeSize, Self.maximumDynamicTypeSize)) }

    var body: some View {
        NavigationStack(path: appViewModel.path(of: .guide)) {
            content
                .navigationTitle(AppStrings.tabGuide)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 番組表を広く使うため、検索欄は置かずにボタンから別の画面で開く
                    if viewModel.state.canSearch {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(AppStrings.searchTitle, systemImage: "magnifyingglass") { appViewModel.send(.push(.search)) }
                                .accessibilityIdentifier("guide.search")
                        }
                    }
                }
                .appRoutes()
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        let state = viewModel.state
        if !state.hasGuide {
            // Mirakurun がなくてもタブは消さず (HIG)、何ができるかと設定のしかたを案内する
            ContentUnavailableView {
                Label(AppStrings.guideSetupTitle, systemImage: "calendar")
            } description: {
                Text(
                    AppStrings.guideSetupHelp)
            } actions: {
                Button(AppStrings.commonOpenSettings) { showSettings() }
                    .buttonStyle(.borderedProminent)
            }
        } else if !state.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.columns.isEmpty {
            ContentUnavailableView {
                Label(AppStrings.guideLoadFailed, systemImage: "calendar.badge.exclamationmark")
            } description: {
                Text(AppStrings.guideConnectionHelp)
            } actions: {
                Button(AppStrings.commonRetry) { viewModel.send(.load) }
            }
        } else {
            // 毎分、今の時刻の線を動かす。表に出す時間も正時ごとに進むので、state もここで読み直す
            TimelineView(.periodic(from: .now, by: 60)) { context in
                grid(viewModel.state, now: context.date)
            }
            .dynamicTypeSize(...Self.maximumDynamicTypeSize)
            // 上に積むと日付の横スクロールが先に見つかり、下へスクロールしてもタブバーが小さくならないので、表の上に重ねる
            .safeAreaBar(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if state.bands.count > 1 {
                        BandPicker(bands: state.bands, selected: state.band)
                    }
                    DayPicker(days: state.days, selected: state.selectedDay) { viewModel.send(.selectDay($0)) }
                }
            }
        }
    }

    private func grid(_ state: GuideGridViewModel.State, now: Date) -> some View {
        let window = state.windowStart...state.windowEnd
        let columns = state.columns
        let metrics = metrics
        let height = CGFloat(state.hourLabels.count * 60) * metrics.pointsPerMinute
        // 縦横を 1 つのスクロールにまとめ、局名の行と時刻の列はスクロール量に合わせてずらして重ねる
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns) { column in
                    ProgramColumn(column: column, window: window, metrics: metrics) { program in
                        appViewModel.send(.push(.programDetail(programID: program.id, channelCode: column.channelCode)))
                    }
                }
            }
            .frame(height: height, alignment: .top)
            .overlay(alignment: .topLeading) {
                // 今の時刻の線 (今日を見ているときだけ)
                if state.isToday {
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
            PinnedTimeColumn(window: window, hourLabels: state.hourLabels, height: height, metrics: metrics, origin: scrollOrigin)
                // 表示している範囲で切る (列そのものは 24 時間分の高さがある)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                // 重ねた行と列の上からでもスクロールできるようにする
                .allowsHitTesting(false)
                // 番組の枠ごとに局名と時刻を読み上げるので、重ねた行と列は読まない
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            PinnedHeader(channelNames: columns.map(\.channelName), metrics: metrics, origin: scrollOrigin)
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
        viewModel.send(.load)
        await waitWhileBusy(viewModel)
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
    let hourLabels: [String]
    let height: CGFloat
    let metrics: GuideMetrics
    let origin: ScrollOrigin

    var body: some View {
        TimeColumn(window: window, hourLabels: hourLabels, metrics: metrics)
            .frame(height: height, alignment: .top)
            .offset(y: metrics.headerHeight + origin.value.y)
    }
}

/// 上に固定する局名の行。横のスクロールにだけ合わせて動かす
private struct PinnedHeader: View {
    let channelNames: [String]
    let metrics: GuideMetrics
    let origin: ScrollOrigin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(channelNames.enumerated()), id: \.offset) { _, name in
                Text(name)
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
    /// 正時ごとの時刻 (朝 4 時より前は前の日の続きとして 24〜27 時。ViewModel が作る)
    let hourLabels: [String]
    let metrics: GuideMetrics

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(hourLabels.enumerated()), id: \.offset) { hour, label in
                let date = window.lowerBound.addingTimeInterval(TimeInterval(hour * 3600))
                Text(label)
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
    let column: GuideColumn
    let window: ClosedRange<Date>
    let metrics: GuideMetrics
    var onSelect: (ProgramItem) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // 番組は、ViewModel が表に出す時間にかかるものだけにしてある
            ForEach(column.programs) { program in
                let top = metrics.offset(of: program.start, in: window)
                let bottom = metrics.offset(of: program.end, in: window)
                Button {
                    onSelect(program)
                } label: {
                    ProgramCell(program: program, channelName: column.channelName)
                        .frame(width: metrics.columnWidth, height: max(1, bottom - top), alignment: .topLeading)
                        .clipped()
                }
                .buttonStyle(.plain)
                .offset(y: top)
            }
        }
        // VoiceOver のローターで局ごとに移れるようにする
        .accessibilityElement(children: .contain)
        .accessibilityLabel(column.channelName)
        .frame(width: metrics.columnWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { GridLine(axis: .vertical) }
    }
}

private struct ProgramCell: View {
    let program: ProgramItem
    let channelName: String
    private var isReserved: Bool { program.isReserved }

    var body: some View {
        // 毎分描き直すので、作ったときではなく今の時刻で放送中か見る
        let now = Date()
        let isOnAir = program.start <= now && now < program.end
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
        let time =
            AppStrings.programTimeRange(
                program.start.formatted(date: .omitted, time: .shortened), program.end.formatted(date: .omitted, time: .shortened))
        var parts = [isOnAir ? AppStrings.programOnAirTime(time) : time, program.name, channelName]
        if let genre = program.genreName { parts.append(genre) }
        if isReserved { parts.append(AppStrings.reservationReserved) }
        return parts.joined(separator: "、")
    }

    /// ジャンル (ARIB の大分類) ごとの色
    private var genreColor: Color {
        switch program.genre {
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
    let days: [GuideDay]
    let selected: Date?
    let onSelect: (Date?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { chip($0) }
            }
            .padding(.horizontal, DesignDimensions.spacingOuter)
            .padding(.bottom, 8)
        }
    }

    private func chip(_ day: GuideDay) -> some View {
        let isSelected = selected == day.date
        return Button {
            onSelect(day.date)
        } label: {
            Text(day.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : color(day.kind))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(.fill.tertiary), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func color(_ kind: GuideDayKind) -> Color {
        switch kind {
        case .saturday: .blue
        case .sunday: .red
        case .weekday: .primary
        }
    }
}
#endif
