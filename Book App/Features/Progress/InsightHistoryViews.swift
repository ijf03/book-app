import SwiftUI
import Charts

struct InsightFinishedBooks: View {
    let months: [ReadingInsights.Month]
    @State private var expanded = Set<Date>()
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Books finished").font(AppTypography.title)
                ForEach(months) { month in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(alignment: .center, spacing: AppSpacing.sm) {
                            Text(month.date, format: .dateTime.month(.abbreviated).year())
                                .font(AppTypography.caption)
                            ScrollView(.horizontal) {
                                HStack(spacing: AppSpacing.xs) {
                                    ForEach(expanded.contains(month.id) ? month.books : Array(month.books.prefix(5))) { book in
                                        BookCoverView(url: book.coverURL)
                                            .frame(width: AppLayout.insightCoverWidth, height: AppLayout.insightCoverWidth * 1.5)
                                            .accessibilityLabel(book.title)
                                    }
                                }
                            }.scrollIndicators(.hidden)
                            if month.books.count > 5 {
                                Button {
                                    if !expanded.insert(month.id).inserted { expanded.remove(month.id) }
                                } label: {
                                    Text(expanded.contains(month.id) ? "−" : "+\(month.books.count - 5)")
                                }
                                .frame(minWidth: AppLayout.minimumTapTarget, minHeight: AppLayout.minimumTapTarget)
                                .accessibilityLabel(expanded.contains(month.id) ? "Show fewer covers" : "Show all finished book covers")
                            }
                            Text(month.books.count.formatted()).font(AppTypography.headline)
                        }
                        Divider()
                    }
                }
                if months.isEmpty { Text("No dated completions yet.").foregroundStyle(Color.textSecondary) }
            }
        }
    }
}

struct InsightStreakView: View {
    let insights: ReadingInsights
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Your reading streak").font(AppTypography.title)
                Text("Purple: best streak · Dark grey: read · ★: finished a book")
                    .font(AppTypography.caption)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? AppLayout.insightCalendarWidth * 2 : AppLayout.insightCalendarWidth))], alignment: .leading, spacing: AppSpacing.md) {
                    ForEach(insights.months) { month in InsightCalendarMonth(month: month) }
                }
                Text("\(insights.currentStreak) days current · \(insights.longestStreak) days best")
                    .font(AppTypography.headline)
                if let start = insights.longestStart, let end = insights.longestEnd {
                    Label("Your longest streak in this period was \(insights.longestStreak) days, from \(start.formatted(date: .abbreviated, time: .omitted)) to \(end.formatted(date: .abbreviated, time: .omitted)).", systemImage: "sparkles")
                        .font(AppTypography.caption)
                } else {
                    Text("Finish a timed reading session to begin your streak.").font(AppTypography.caption)
                }
                Text("Days include reading check-ins or finished sessions with positive reading time. Streaks are limited to the selected period; a current streak may end yesterday.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }
}

private struct InsightCalendarMonth: View {
    let month: ReadingInsights.Month
    private let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 7)
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(month.date, format: .dateTime.month(.wide).year()).font(AppTypography.headline)
            LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                ForEach(0..<7, id: \.self) { day in
                    Text(Calendar.current.veryShortStandaloneWeekdaySymbols[day])
                        .font(AppTypography.caption).accessibilityHidden(true)
                }
                ForEach(0..<month.leadingDays, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
                }
                ForEach(month.days) { day in
                    Text(day.number.formatted())
                        .font(AppTypography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .foregroundStyle(day.active ? Color.surface : Color.textPrimary)
                        .background(day.best ? Color.appAccent : day.active ? Color.textSecondary : Color.clear, in: Circle())
                        .overlay {
                            if day.finished { Circle().stroke(Color.appAccent, lineWidth: 2) }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if day.finished {
                                Image(systemName: "star.fill")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(Color.appAccent)
                                    .background(Color.surface, in: Circle())
                                    .offset(x: AppSpacing.xs, y: AppSpacing.xs)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel("\(day.date.formatted(date: .complete, time: .omitted)): \(day.best ? String(localized: "best streak") : day.active ? String(localized: "read") : String(localized: "no recorded reading"))\(day.finished ? String(localized: ", finished a book") : "")")
                }
            }
        }
    }
}

struct InsightCountChart: View {
    let title: LocalizedStringResource
    let counts: [ReadingInsights.Count]
    let empty: LocalizedStringResource
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(title).font(AppTypography.title)
                if counts.allSatisfy({ $0.count == 0 }) {
                    Text(empty).foregroundStyle(Color.textSecondary)
                }
                ForEach(counts) { item in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                            Text(item.name)
                                .font(AppTypography.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: AppSpacing.sm)
                            Text(item.count.formatted())
                                .font(AppTypography.headline)
                                .monospacedDigit()
                                .fixedSize()
                        }
                        Chart {
                            BarMark(xStart: .value("Start", 0), xEnd: .value("Books", max(counts.map(\.count).max() ?? 1, 1)),
                                    y: .value("Category", item.name))
                                .foregroundStyle(Color.accentTint)
                            BarMark(xStart: .value("Start", 0), xEnd: .value("Books", item.count),
                                    y: .value("Category", item.name))
                                .foregroundStyle(Color.chart2)
                        }
                        .chartXScale(domain: 0...max(counts.map(\.count).max() ?? 1, 1))
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: AppSpacing.md)
                        .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.name)
                    .accessibilityValue("\(item.count) books")
                }
            }
        }
    }
}

#Preview("Wrapping author labels") {
    ScrollView {
        InsightCountChart(title: "Most-read authors", counts: [
            .init(name: "Andy Weir", count: 1),
            .init(name: "An author with a very long name that needs multiple lines", count: 3),
            .init(name: "Rebecca Yarros", count: 2)
        ], empty: "No completed books")
        .padding(AppSpacing.md)
    }
    .background(Color.surfaceSecondary)
    .dynamicTypeSize(.accessibility2)
}

struct InsightPaceView: View {
    let insights: ReadingInsights
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Your reading pace").font(AppTypography.title)
                Chart(insights.months) { month in
                    if let pace = month.pagesPerHour {
                        BarMark(x: .value("Month", month.date, unit: .month), y: .value("Pages / hour", pace))
                            .foregroundStyle(Color.chart2)
                            .accessibilityLabel(Text(month.date, format: .dateTime.month(.wide).year()))
                            .accessibilityValue("\(pace.formatted(.number.precision(.fractionLength(1)))) pages per hour")
                    }
                }
                .chartYAxisLabel("Pages / hour")
                .frame(height: AppLayout.statisticsChartHeight)
                value("Pages / hour", insights.pagesPerHour)
                value("Pages / session", insights.pagesPerSession)
                value("Days / finished book", insights.daysToFinish)
                value("Active days / complete month", insights.activeDaysPerMonth)
                Text("Pace uses new page coverage and unpaused time from finished sessions with page records. Pages per session excludes sessions without page records.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                Text("Days per book measures first recorded finished session through completion, including both calendar days (\(insights.completionSamples) books). It may underestimate books started before tracking. Monthly activity excludes partial months and includes zero-activity complete months.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }
    private func value(_ title: LocalizedStringResource, _ value: Double?) -> some View {
        LabeledContent {
            Text(value.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? String(localized: "Not enough data"))
                .font(AppTypography.headline)
        } label: { Text(title) }
    }
}
