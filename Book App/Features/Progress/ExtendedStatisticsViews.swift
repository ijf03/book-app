import SwiftUI
import Charts

struct InsightPieChart: View {
    let title: LocalizedStringResource
    let counts: [ReadingInsights.Count]
    @ScaledMetric(relativeTo: .body) private var chartHeight = AppLayout.statisticsChartHeight

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(title).font(AppTypography.title).accessibilityAddTraits(.isHeader)
                if counts.isEmpty {
                    Text("No dated completed books in this period.").foregroundStyle(Color.textSecondary)
                } else {
                    Chart(counts) { item in
                        SectorMark(angle: .value("Books", item.count), innerRadius: .ratio(0.65))
                            .foregroundStyle(by: .value("Category", item.name))
                            .accessibilityLabel(item.name)
                            .accessibilityValue("\(item.count) books")
                    }
                    .chartForegroundStyleScale(range: [Color.appAccent, Color.chart2, Color.textSecondary, Color.chart4])
                    .chartLegend(.hidden)
                    .frame(height: chartHeight)
                    // Always provide text outside the chart, including unrecorded categories.
                    ForEach(counts) { item in
                        HStack(alignment: .top) {
                            Text(item.name)
                            Spacer()
                            Text(item.count.formatted()).monospacedDigit()
                        }
                        .font(AppTypography.body)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

struct BookComparisonView: View {
    let books: [ExtendedReadingStatistics.BookSummary]
    @State private var firstID = ""
    @State private var secondID = ""
    @State private var metric: ComparisonMetric = .pages
    private enum ComparisonMetric: String, CaseIterable, Identifiable {
        case pages, hours, pace
        var id: Self { self }
        var title: LocalizedStringResource {
            switch self { case .pages: "Pages"; case .hours: "Hours"; case .pace: "Pages/hour" }
        }
        func value(_ book: ExtendedReadingStatistics.BookSummary) -> Double? {
            switch self {
            case .pages: book.pages.map(Double.init)
            case .hours: book.sessions > 0 ? Double(book.seconds) / 3600 : nil
            case .pace: book.pace
            }
        }
    }
    private var selected: [ExtendedReadingStatistics.BookSummary] {
        books.filter { $0.id == firstID || $0.id == secondID }
    }
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Compare books").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                Text("Sessions, pages and pace use the selected period. Completion metrics use recorded history up to completion for books finished in this period.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                if books.isEmpty {
                    Text("Add books to your library to compare them.")
                } else {
                    Picker("First book", selection: $firstID) {
                        Text("Choose a book").tag("")
                        ForEach(books) { Text($0.title).tag($0.id) }
                    }
                    Picker("Second book", selection: $secondID) {
                        Text("Choose a book").tag("")
                        ForEach(books.filter { $0.id != firstID }) { Text($0.title).tag($0.id) }
                    }
                    Picker("Compare", selection: $metric) {
                        ForEach(ComparisonMetric.allCases) { Text($0.title).tag($0) }
                    }.accessibleSegmentedPicker()
                    if selected.isEmpty { Text("Select up to two books to see recorded metrics.") }
                    ForEach(selected) { book in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(book.title).font(AppTypography.headline)
                            if let value = metric.value(book) {
                                Chart {
                                    BarMark(x: .value("Value", value), y: .value("Book", book.id))
                                        .foregroundStyle(Color.appAccent)
                                }
                                .chartXScale(domain: 0...max(1, selected.compactMap { metric.value($0) }.max() ?? 1))
                                .chartXAxis(.hidden).chartYAxis(.hidden)
                                .frame(height: AppSpacing.md)
                                .accessibilityHidden(true)
                                Text(metric.title) + Text(": \(value.formatted(.number.precision(.fractionLength(1))))")
                            } else { Text("Not recorded") }
                            Text("\(book.sessions) finished sessions")
                            Text("Recorded time: \(Duration.seconds(book.seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))")
                            if let pace = book.pace { Text("Pace: \(pace.formatted(.number.precision(.fractionLength(1)))) pages/hour") }
                            if let days = book.daysToFinish { Text("Recorded span to finish: \(days) calendar days") }
                            if let seconds = book.finishSeconds {
                                Text("Recorded time to finish: \(Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))")
                            }
                            if let rating = book.rating { Text("Rating: \(rating) / 5") }
                        }
                        .font(AppTypography.body)
                    }
                    Text("Pace is new page coverage divided by unpaused time in sessions with page records. Missing page records, audio positions and percentages are not converted to pages.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
        }
        .onChange(of: firstID) { _, value in if secondID == value { secondID = "" } }
    }
}

struct RatingsByBookTypeView: View {
    let statistics: ExtendedReadingStatistics
    @State private var byFormat = false
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Ratings by book type").font(AppTypography.title).accessibilityAddTraits(.isHeader)
            Picker("Group ratings by", selection: $byFormat) {
                Text("Fiction / non-fiction").tag(false)
                Text("Format").tag(true)
            }
            .pickerStyle(.menu)
            Text("Current ratings, selected by review creation date. Missing or deleted book details appear as Not recorded.")
                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            if (byFormat ? statistics.ratingsByFormat : statistics.ratingsByType).isEmpty {
                Text("Add a review to see ratings by type.")
            }
            ForEach(byFormat ? statistics.ratingsByFormat : statistics.ratingsByType) { group in
                InsightCountChart(title: LocalizedStringResource(stringLiteral: group.name),
                                  counts: group.ratings, empty: "No ratings recorded.")
            }
        }
    }
}

struct ExtendedStatisticsSection: View {
    let statistics: ReadingStatistics
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            BookComparisonView(books: statistics.extended.books)
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Average recorded time to finish").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                    if let seconds = statistics.extended.averageFinishSeconds {
                        Text(Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))
                            .font(AppTypography.title)
                    } else { Text("Not enough recorded sessions") }
                    Text("\(statistics.extended.finishSamples) completed books with positive recorded time. Includes finished sessions up to completion, excluding pauses. Untracked reading time is unknown.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
            InsightPieChart(title: "Fiction and non-fiction", counts: statistics.extended.types)
            InsightPieChart(title: "Languages read", counts: statistics.extended.languages)
            InsightCountChart(title: "How books left you feeling", counts: statistics.extended.moods,
                              empty: "Complete a book and record your mood in its review.")
            Text("Mood charts use current review feelings for books completed in the selected period.")
                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            RatingsByBookTypeView(statistics: statistics.extended)
        }
    }
}

#Preview("Comparison empty") {
    ScrollView { ExtendedStatisticsSection(statistics: ReadingStatistics()).padding(AppSpacing.md) }
        .background(Color.surfaceSecondary)
}
