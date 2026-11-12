import SwiftUI
import Observation

nonisolated enum InsightGoalPeriod: String, CaseIterable, Identifiable {
    case year, month, week
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self { case .year: "Yearly"; case .month: "Monthly"; case .week: "Weekly" }
    }
    var component: Calendar.Component {
        switch self { case .year: .year; case .month: .month; case .week: .weekOfYear }
    }
}
nonisolated enum InsightGoalMetric: String, CaseIterable, Identifiable {
    case books, pages, days
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self { case .books: "Books finished"; case .pages: "Pages read"; case .days: "Active days" }
    }
}

@MainActor @Observable
final class InsightGoalModel {
    var period: InsightGoalPeriod = .year
    var metric: InsightGoalMetric = .books
    var date = Date()
    var targetText = ""
    private(set) var target: Int?
    private(set) var progress = 0
    private(set) var booksPerMonth: Int?
    var error: String?
    let library: LibraryStore
    let sessions: ReadingSessionStore
    private let repository: LocalJSONRepository<[ReadingGoal]>

    init(library: LibraryStore, sessions: ReadingSessionStore) {
        self.library = library
        self.sessions = sessions
        repository = .init(fileName: "reading-goals.json", scope: library.accountScope)
    }

    static func goal(period: InsightGoalPeriod, metric: InsightGoalMetric, date: Date,
                     target: Int, calendar: Calendar) -> ReadingGoal {
        let start = calendar.dateInterval(of: period.component, for: date)?.start ?? date
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        let year = calendar.component(.year, from: date)
        let key = "\(parts.year ?? year)-\(parts.month ?? 1)-\(parts.day ?? 1)"
        return ReadingGoal(year: year, target: target, period: period.rawValue, metric: metric.rawValue, periodKey: key)
    }

    func refresh() async {
        guard library.accountScope?.isActive != false else { return }
        let calendar = Calendar.current, now = Date()
        let chosen = Self.goal(period: period, metric: metric, date: date, target: 1, calendar: calendar)
        let goals: [ReadingGoal]
        do { goals = try repository.load(default: []); error = nil }
        catch { self.error = String(localized: "Goals couldn’t be loaded. Please retry."); return }
        target = goals.first { $0.id == chosen.id }?.target
        let source = StatisticsInput(books: library.books, sessions: sessions.sessions, reviews: [], checkIns: library.checkIns.entries)
        guard let interval = calendar.dateInterval(of: period.component, for: date),
              let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return }
        let selection = StatisticsSelection(period: .custom, from: interval.start, to: min(last, now))
        let selectedMetric = metric
        let yearly = goals.first { $0.id == String(calendar.component(.year, from: now)) }
        let task = Task.detached {
            let stats = ReadingStatisticsCalculator.calculate(source, selection: selection, calendar: calendar, now: now)
            let value: Int
            switch selectedMetric {
            case .books: value = stats.completedBooks
            case .pages: value = stats.pages
            case .days: value = stats.activeDays.count
            }
            let yearStats = ReadingStatisticsCalculator.calculate(source, selection: .init(period: .year, from: now, to: now), calendar: calendar, now: now)
            let remaining = yearly.map { max(0, $0.target - yearStats.completedBooks) }
            let monthsLeft = 13 - calendar.component(.month, from: now)
            return (value, remaining.map { Int(ceil(Double($0) / Double(monthsLeft))) })
        }
        let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard !Task.isCancelled, library.accountScope?.isActive != false else { return }
        progress = result.0
        booksPerMonth = result.1
    }

    func save() -> Bool {
        guard let target = ReadingGoalsViewModel.validTarget(targetText) else {
            error = String(localized: "Enter a whole number from 1 to 10,000."); return false
        }
        let goal = Self.goal(period: period, metric: metric, date: date, target: target, calendar: .current)
        do {
            var goals = try repository.load(default: [])
            goals.removeAll { $0.id == goal.id }
            goals.append(goal)
            try repository.save(goals)
            self.target = target
            error = nil
            return true
        } catch { self.error = String(localized: "Your goal couldn’t be saved. Please retry."); return false }
    }
}

struct InsightGoalView: View {
    @State private var model: InsightGoalModel
    private var showsMonthlyInsight = true
    @State private var editing = false
    @State private var revision = 0

    init(library: LibraryStore, sessions: ReadingSessionStore) {
        _model = State(initialValue: InsightGoalModel(library: library, sessions: sessions))
    }

    init(model: InsightGoalModel, showsMonthlyInsight: Bool = true) {
        _model = State(initialValue: model)
        self.showsMonthlyInsight = showsMonthlyInsight
    }

    private var refreshKey: String {
        "\(model.period.rawValue)-\(model.metric.rawValue)-\(model.date)-\(revision)-\(model.library.books.hashValue)-\(model.sessions.sessions.hashValue)-\(model.library.checkIns.entries.hashValue)-\(model.library.accountScope?.cloudRevision ?? 0)"
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Make reading your own").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                ViewThatFits(in: .horizontal) {
                    HStack { selectors }
                    VStack(alignment: .leading) { selectors }
                }
                DatePicker("Goal period", selection: $model.date, in: ...Date(), displayedComponents: .date)
                if let target = model.target {
                    Text("\(model.progress) of \(target)").font(AppTypography.title)
                    SwiftUI.ProgressView(value: min(Double(model.progress), Double(target)), total: Double(target))
                        .tint(Color.appAccent)
                        .accessibilityLabel(Text(model.metric.title))
                        .accessibilityValue("\(model.progress) of \(target)")
                    Text(model.metric.title).font(AppTypography.caption)
                } else {
                    Text("Choose a target for this period.").foregroundStyle(Color.textSecondary)
                }
                Button(model.target == nil ? "Set goal" : "Edit goal") {
                    model.targetText = model.target.map(String.init) ?? ""
                    editing = true
                }.buttonStyle(AppButtonStyle(kind: .secondary))
                if showsMonthlyInsight, let count = model.booksPerMonth {
                    Label("Read \(count) books per month, including this month, to reach your current yearly book goal.", systemImage: "sparkles")
                        .font(AppTypography.caption)
                }
                if let error = model.error {
                    Text(error).foregroundStyle(Color.textSecondary)
                    Button("Retry") { revision += 1 }
                }
            }
        }
        .task(id: refreshKey) { await model.refresh() }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    Text(model.period.title)
                    Text(model.metric.title)
                    TextField("Target", text: $model.targetText).keyboardType(.numberPad)
                    Text("Pages use new page coverage in finished sessions. Active days include reading check-ins or recorded reading time.")
                        .font(AppTypography.caption)
                    if let error = model.error { Text(error) }
                }
                .navigationTitle("Reading goal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { if model.save() { revision += 1; editing = false } }
                            .disabled(ReadingGoalsViewModel.validTarget(model.targetText) == nil)
                    }
                }
            }
        }
    }

    @ViewBuilder private var selectors: some View {
        Picker("Frequency", selection: $model.period) {
            ForEach(InsightGoalPeriod.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.menu)
        Picker("Track", selection: $model.metric) {
            ForEach(InsightGoalMetric.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.menu)
    }
}
