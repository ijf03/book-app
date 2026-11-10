import SwiftUI
import Charts

struct DetailedStatisticsView: View {
    private let repository: (any BookRepository)?
    @State private var genreMetadata = GenreMetadataViewModel()
    @State private var genreRequest = 0
    @State private var model: DetailedStatisticsViewModel
    @State private var showsPeriod = false
    @State private var showsGenres = false
    @State private var showsShare = false
    @State private var genrePie = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar

    init(library: LibraryStore, sessions: ReadingSessionStore, content: BookContentStore, repository: (any BookRepository)? = nil) {
        self.repository = repository
        _model = State(initialValue: DetailedStatisticsViewModel(library: library, sessions: sessions, content: content))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Button { showsPeriod = true } label: {
                    HStack {
                        Text(model.selection.period.title)
                        Image(systemName: "chevron.down").accessibilityHidden(true)
                    }
                    .font(AppTypography.headline)
                    .padding(AppSpacing.md)
                    .background(Color.accentTint, in: Capsule())
                }
                .accessibilityLabel("Choose statistics period")
                .accessibilityValue(Text(model.selection.period.title))
                .accessibilityIdentifier("stats.choosePeriod")
                Menu {
                    ForEach(model.years, id: \.self) { year in
                        Button(String(year)) { model.selectYear(year) }
                    }
                } label: { Label("Explore a year", systemImage: "calendar") }
                if let interval = model.statistics.interval {
                    Text("\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(interval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
                if model.isCalculating {
                    SwiftUI.ProgressView("Updating statistics…")
                } else {
                    if !model.statistics.hasData {
                        ContentUnavailableView("No data for this period", systemImage: "chart.bar",
                                               description: Text("Finish a reading session, complete a book, or add a review. You can also choose another period."))
                    }
                    StatisticsMetrics(statistics: model.statistics)
                    InsightGoalView(model: model.goalModel, showsMonthlyInsight: false)
                    InsightFinishedBooks(months: model.statistics.insights.months)
                    if let count = model.goalModel.booksPerMonth {
                        AppCard {
                            Label("Read \(count) books per month, including this month, to reach your current yearly book goal.", systemImage: "sparkles")
                                .font(AppTypography.body)
                        }
                    }
                    InsightStreakView(insights: model.statistics.insights)
                    Picker("Genre chart style", selection: $genrePie) {
                        Text("Genre bars").tag(false)
                        Text("Genre pie").tag(true)
                    }.pickerStyle(.segmented)
                    if genrePie {
                        InsightPieChart(title: "Your reading tastes", counts: model.statistics.insights.genres)
                    } else {
                        InsightCountChart(title: "Your reading tastes", counts: model.statistics.insights.genres, empty: "Add genres to your completed books to discover your reading tastes.")
                    }
                    if let genre = model.statistics.insights.genres.first {
                        Label("\(genre.name) is your most-read tagged genre: \(genre.count) books.", systemImage: "sparkles")
                            .font(AppTypography.caption)
                    }
                    Text("\(model.statistics.insights.untaggedBooks) completed books have no genre tag.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    if repository != nil {
                        Button("Fill missing genres from Open Library") { genreRequest += 1 }
                            .disabled(genreMetadata.isLoading)
                        if genreMetadata.isLoading { SwiftUI.ProgressView("Looking up genres…") }
                        if let message = genreMetadata.message {
                            Text(message).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                        }
                    }
                    Text("One primary genre per read, based on recognised Open Library subjects or your edits.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    Button("Edit book details for insights") { showsGenres = true }
                    InsightCountChart(title: "How you rate", counts: model.statistics.insights.ratings, empty: "Add a review to see your rating distribution.")
                    InsightCountChart(title: "Most-read authors", counts: Array(model.statistics.insights.authors.prefix(10)), empty: "Complete a book to discover your most-read authors.")
                    InsightRhythmView(months: model.statistics.insights.months, comparisonMonths: model.statistics.insights.comparisonMonths, initiallyMonthly: model.selection.period == .month)
                    InsightPaceView(insights: model.statistics.insights)
                    StatisticsFormatChart(formats: model.statistics.formats, total: model.statistics.completedBooks)
                    StatisticsActivityChart(statistics: model.statistics)
                    ExtendedStatisticsSection(statistics: model.statistics)
                    StatisticsDefinitions(undatedBooks: model.statistics.undatedCompletedBooks)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Reading insights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsShare = true } label: { Label("Share statistics", systemImage: "square.and.arrow.up") }
                    .disabled(model.isCalculating)
            }
        }
        .sheet(isPresented: $showsShare) { StatisticsShareView(statistics: model.statistics) }
        .sheet(isPresented: $showsGenres) { InsightGenreEditor(library: model.library) }
        .sheet(isPresented: $showsPeriod) {
            StatisticsPeriodSheet(selection: model.selection, onApply: model.apply)
        }
        .task { model.start() }
        .task(id: genreRequest) {
            guard genreRequest > 0, let repository else { return }
            await genreMetadata.fillMissing(library: model.library, repository: repository)
        }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh(calendar: calendar) }
        }
    }
}

private struct StatisticsMetrics: View {
    let statistics: ReadingStatistics
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        StatisticsCardLayout(columns: typeSize.isAccessibilitySize ? 1 : 2, spacing: AppSpacing.md) {
            metric("Books completed", value: statistics.completedBooks.formatted(), detail: "Completed reads, including rereads")
            metric("Recorded reading time", value: Duration.seconds(statistics.seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)), detail: "Finished sessions, excluding pauses")
            metric("Recorded pages read", value: statistics.sessionsWithPages == 0 ? String(localized: "Not recorded") : statistics.pages.formatted(), detail: "New page coverage in finished sessions")
            metric("Average rating", value: statistics.averageRating.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? String(localized: "Not rated"), detail: "Out of 5 · review creation date")
        }
        Text("\(statistics.sessions) finished sessions · \(statistics.sessionsWithPages) with page records · \(statistics.ratingCount) reviews")
            .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
    }

    private func metric(_ title: LocalizedStringResource, value: String, detail: LocalizedStringResource) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title).font(AppTypography.headline)
                Text(value).font(AppTypography.title).monospacedDigit()
                Text(detail).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Measures every card at its column width so all cards fit the tallest content.
private struct StatisticsCardLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    private func dimensions(width: CGFloat, subviews: Subviews) -> (width: CGFloat, height: CGFloat) {
        let cardWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let cardHeight = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
        }.max() ?? 0
        return (cardWidth, cardHeight)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let card = dimensions(width: width, subviews: subviews)
        let rows = (subviews.count + columns - 1) / columns
        return CGSize(width: width, height: CGFloat(rows) * card.height + CGFloat(max(0, rows - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let card = dimensions(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index % columns) * (card.width + spacing),
                            y: bounds.minY + CGFloat(index / columns) * (card.height + spacing)),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: card.width, height: card.height)
            )
        }
    }
}

private struct StatisticsFormatChart: View {
    let formats: [ReadingStatistics.FormatCount]
    let total: Int
    @ScaledMetric(relativeTo: .body) private var chartHeight = AppLayout.statisticsChartHeight

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Completed books by format").font(AppTypography.headline)
                if total == 0 {
                    Text("No completed books for this period.").foregroundStyle(Color.textSecondary)
                } else {
                    Chart(formats) { format in
                        if format.count > 0 {
                            SectorMark(angle: .value("Books", format.count), innerRadius: .ratio(0.68))
                                .foregroundStyle(format.id == "physical" ? Color.appAccent : format.id == "ebook" ? Color.chart2 : format.id == "immersive" ? Color.textSecondary : Color.chart4)
                                .accessibilityLabel(Text(format.title))
                                .accessibilityValue(Text("\(format.count) books"))
                        }
                    }
                    .frame(height: chartHeight)
                    .overlay {
                        VStack(spacing: AppSpacing.xs) {
                            Text(total.formatted()).font(AppTypography.title)
                            Text("books").font(AppTypography.caption)
                        }
                        .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Completed books by format")
                }
                ForEach(formats) { format in
                    LabeledContent {
                        Text("\(format.count) · \((total == 0 ? 0 : Double(format.count) / Double(total)).formatted(.percent.precision(.fractionLength(0))))")
                    } label: {
                        Label {
                            Text(format.title)
                        } icon: {
                            Circle()
                                .fill(format.id == "physical" ? Color.appAccent : format.id == "ebook" ? Color.chart2 : format.id == "immersive" ? Color.textSecondary : Color.chart4)
                                .frame(width: AppSpacing.md, height: AppSpacing.md)
                                .accessibilityHidden(true)
                        }
                    }
                    .font(AppTypography.body)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct StatisticsActivityChart: View {
    let statistics: ReadingStatistics
    @ScaledMetric(relativeTo: .body) private var chartHeight = AppLayout.statisticsChartHeight

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Reading activity").font(AppTypography.headline)
                Text(statistics.bucket.title).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                Text("Finished sessions are assigned to the date they ended.").font(AppTypography.caption)
                if statistics.sessions == 0 {
                    Text("No finished sessions for this period.").foregroundStyle(Color.textSecondary)
                } else {
                    Chart(statistics.activity) { item in
                        BarMark(x: .value("Period", item.start), y: .value("Recorded minutes", Double(item.seconds) / 60))
                            .foregroundStyle(Color.chart4)
                            .accessibilityLabel(Text(item.start, format: .dateTime.year().month().day()))
                            .accessibilityValue(Text("\(item.sessions) sessions, \(item.seconds) seconds, \(item.pages) new pages"))
                    }
                    .chartYAxisLabel("Recorded minutes")
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .frame(height: chartHeight)
                    .accessibilityLabel("Recorded reading time over the selected period")
                    Text("\(statistics.sessions) finished sessions recorded \(statistics.seconds) seconds of reading in this period.")
                        .font(AppTypography.body)
                    DisclosureGroup("Activity as text") {
                        ForEach(statistics.activity) { item in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("\(item.start.formatted(date: .abbreviated, time: .omitted)) – \(item.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                                Text("\(item.sessions) sessions · \(item.seconds) seconds · \(item.pages) pages · \(item.books) books completed")
                            }
                            .font(AppTypography.caption)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

private struct StatisticsDefinitions: View {
    let undatedBooks: Int
    var body: some View {
        AppCard {
            DisclosureGroup("How these statistics are counted") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Dates use this device’s calendar and time zone, including the full To date. A session crossing midnight or a period boundary belongs entirely to its end date; pause locations are not recorded.")
                    Text("Time excludes pauses and unfinished sessions. Pages use only explicit start and end pages from finished sessions. Previously recorded page ranges for the same book are counted once across all history. Current pages, percentages and audio positions are never converted into pages.")
                    Text("Ratings use the current rating of reviews created in this period, including later edits. They are not a historical snapshot of ratings at that time.")
                    Text("Each completed read counts using its saved completion date. Read Again preserves the previous completion and starts a new cycle. Pages are deduplicated within each cycle, so rereading counts again. Reviews remain per book. Deleted books no longer count as completed; retained sessions still count.")
                    if undatedBooks > 0 {
                        Text("\(undatedBooks) completed books have no completion date. They count in All time only and cannot be assigned to an activity date.")
                    }
                }
                .font(AppTypography.body)
                .padding(.top, AppSpacing.md)
            }
        }
    }
}

#Preview("Empty · large text · dark") {
    NavigationStack {
        DetailedStatisticsView(
            library: LibraryStore(books: [], localDataSource: LocalLibraryDataSource()),
            sessions: ReadingSessionStore(sessions: [], localDataSource: LocalReadingSessionDataSource()),
            content: BookContentStore(notes: [], reviews: [], localDataSource: LocalBookContentDataSource())
        )
    }
    .dynamicTypeSize(.accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Book formats") {
    StatisticsFormatChart(formats: [.init(id: "physical", count: 2), .init(id: "ebook", count: 2), .init(id: "audiobook", count: 2)], total: 6)
        .padding(AppSpacing.md)
        .background(Color.surfaceSecondary)
}
