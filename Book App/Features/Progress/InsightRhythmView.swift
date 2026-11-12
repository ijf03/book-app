import SwiftUI
import Charts

struct InsightRhythmView: View {
    let months: [ReadingInsights.Month]
    let comparisonMonths: [ReadingInsights.Month]
    var initiallyMonthly = false
    @State private var monthly = false
    @State private var selectedMonth: Date?
    @State private var metric: InsightGoalMetric = .books

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Patterns & pace").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                Picker("Chart view", selection: $monthly) {
                    Text("Year").tag(false)
                    Text("Month").tag(true)
                }.accessibleSegmentedPicker()
                if monthly {
                    Picker("Explore a month", selection: $selectedMonth) {
                        ForEach(months) { month in
                            Text(month.date, format: .dateTime.month(.wide).year()).tag(Optional(month.date))
                        }
                    }
                    if let current = months.first(where: { $0.date == selectedMonth }) ?? months.last {
                        let previous = comparisonMonths.last { $0.date < current.date }
                        InsightRadarView(current: current, previous: previous)
                    } else { Text("No recorded months to compare yet.") }
                } else {
                    Picker("Activity metric", selection: $metric) {
                        ForEach(InsightGoalMetric.allCases) { Text($0.title).tag($0) }
                    }.accessibleSegmentedPicker()
                    Chart(months) { month in
                        BarMark(x: .value("Month", month.date, unit: .month),
                                y: .value("Count", value(month)))
                            .foregroundStyle(Color.chart2)
                            .accessibilityLabel(Text(month.date, format: .dateTime.month(.wide).year()))
                            .accessibilityValue("\(value(month)) \(String(localized: metric.title))")
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                    .frame(height: AppLayout.statisticsChartHeight)
                    Text("Month-by-month totals for the selected date range. Partial months include only selected days.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    DisclosureGroup("Monthly totals as text") {
                        ForEach(months) { month in
                            LabeledContent {
                                Text(value(month).formatted())
                            } label: { Text(month.date, format: .dateTime.month(.wide).year()) }
                        }
                    }
                }
            }
        }
        .onAppear { monthly = initiallyMonthly; selectedMonth = months.last(where: { $0.date <= Date() })?.date }
        .onChange(of: initiallyMonthly) { _, value in monthly = value }
        .onChange(of: months.map(\.date)) { _, dates in
            if !dates.contains(selectedMonth ?? .distantPast) { selectedMonth = dates.last(where: { $0 <= Date() }) }
        }
    }
    private func value(_ month: ReadingInsights.Month) -> Int {
        switch metric { case .books: month.books.count; case .pages: month.pages; case .days: month.activeDays }
    }
}

private struct InsightRadarView: View {
    let current: ReadingInsights.Month
    let previous: ReadingInsights.Month?
    private let titles: [LocalizedStringResource] = ["Books", "Pages", "Reading hours", "Active days", "Pages / hour", "Session minutes"]
    @ScaledMetric private var height = AppLayout.insightRadarHeight

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Your month at a glance").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.35
                func point(_ index: Int, _ ratio: Double) -> CGPoint {
                    let angle = Double(index) * .pi / 3 - .pi / 2
                    return CGPoint(x: center.x + cos(angle) * radius * ratio, y: center.y + sin(angle) * radius * ratio)
                }
                func polygon(_ values: [Double]) -> Path {
                    Path { path in
                        for index in 0..<6 {
                            let point = point(index, values[index])
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                        path.closeSubpath()
                    }
                }
                for level in 1...4 {
                    context.stroke(polygon(Array(repeating: Double(level) / 4, count: 6)), with: .color(.border), lineWidth: 1)
                }
                let left = current.radar, right = previous?.radar ?? Array(repeating: 0, count: 6)
                let scales = zip(left, right).map { max($0, $1, 1) }
                if previous != nil {
                    let path = polygon(zip(right, scales).map { $0 / $1 })
                    context.fill(path, with: .color(Color.textSecondary.opacity(0.15)))
                    context.stroke(path, with: .color(.textSecondary), style: StrokeStyle(lineWidth: 2, dash: [4]))
                }
                let path = polygon(zip(left, scales).map { $0 / $1 })
                context.fill(path, with: .color(Color.appAccent.opacity(0.2)))
                context.stroke(path, with: .color(.appAccent), lineWidth: 2)
                for index in 0..<6 {
                    context.draw(Text((index + 1).formatted()).font(AppTypography.headline), at: point(index, 1.3))
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
            Text("Purple: selected month · Dashed grey: previous available month")
                .font(AppTypography.caption)
            Text("Each axis is scaled to the larger of the two values (100%). This compares these months, not a score or target. Missing pace/session data is drawn at zero; actual values are listed below.")
                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            ForEach(0..<6, id: \.self) { index in
                LabeledContent {
                    Text("\(display(current, index)) / \(previous.map { display($0, index) } ?? String(localized: "No previous month"))")
                } label: { Text("\(index + 1). \(String(localized: titles[index]))") }
                .font(AppTypography.caption).accessibilityElement(children: .combine)
            }
        }
    }

    private func display(_ month: ReadingInsights.Month, _ index: Int) -> String {
        if index == 4 && month.pagesPerHour == nil || index == 5 && month.sessionMinutes == nil {
            return String(localized: "Not recorded")
        }
        return month.radar[index].formatted(.number.precision(.fractionLength(1)))
    }
}
