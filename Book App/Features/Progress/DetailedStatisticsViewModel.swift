import Foundation
import Observation

@MainActor
@Observable
final class DetailedStatisticsViewModel {
    private(set) var selection: StatisticsSelection
    private(set) var years: [Int] = []
    private(set) var statistics = ReadingStatistics()
    private(set) var isCalculating = false
    private(set) var calendar: Calendar
    let library: LibraryStore
    let sessionsForGoals: ReadingSessionStore
    let goalModel: InsightGoalModel
    private let sessions: ReadingSessionStore
    private let content: BookContentStore
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var observationID = UUID()
    @ObservationIgnored private var calculationID = UUID()
    @ObservationIgnored private var worker: Task<ReadingStatistics, Never>?
    @ObservationIgnored private var publisher: Task<Void, Never>?

    init(library: LibraryStore, sessions: ReadingSessionStore, content: BookContentStore,
         calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.library = library
        self.sessions = sessions
        self.sessionsForGoals = sessions
        self.goalModel = InsightGoalModel(library: library, sessions: sessions)
        self.content = content
        self.calendar = calendar
        self.now = now
        let today = now()
        selection = .init(period: .year, from: calendar.dateInterval(of: .month, for: today)?.start ?? today, to: today)
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        observeSources()
    }

    func stop() {
        isObserving = false
        observationID = UUID()
        calculationID = UUID()
        worker?.cancel()
        publisher?.cancel()
        isCalculating = false
    }

    func selectYear(_ year: Int) {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let next = calendar.date(byAdding: .year, value: 1, to: start),
              let last = calendar.date(byAdding: .day, value: -1, to: next) else { return }
        apply(.init(period: .custom, from: start, to: min(last, now())))
    }

    func apply(_ selection: StatisticsSelection) {
        guard selection.validation(calendar: calendar, now: now()) == nil else { return }
        self.selection = selection
        refresh()
    }

    func refresh(calendar: Calendar? = nil) {
        if let calendar { self.calendar = calendar }
        calculate(snapshot())
    }

    private func snapshot() -> StatisticsInput {
        guard library.accountScope?.isActive != false else { return StatisticsInput() }
        return StatisticsInput(books: library.books, sessions: sessions.sessions, reviews: content.reviews, checkIns: library.checkIns.entries)
    }

    private func observeSources() {
        guard isObserving else { return }
        let token = UUID()
        observationID = token
        let input = withObservationTracking {
            snapshot()
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isObserving, self.observationID == token else { return }
                self.observeSources()
            }
        }
        calculate(input)
    }

    private func calculate(_ input: StatisticsInput) {
        worker?.cancel()
        publisher?.cancel()
        let token = UUID()
        calculationID = token
        guard library.accountScope?.isActive != false else {
            statistics = ReadingStatistics()
            isCalculating = false
            return
        }
        let selection = selection, calendar = calendar, date = now()
        let dates = input.completedReads.compactMap(\.completedAt) + input.sessions.compactMap(\.end) + input.reviews.map(\.createdAt) + input.checkIns.compactMap { $0.date(calendar: calendar) }
        years = Set((dates.filter { $0 <= date } + [date]).map { calendar.component(.year, from: $0) }).sorted(by: >)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            var result = ReadingStatisticsCalculator.calculate(input, selection: selection, calendar: calendar, now: date)
            let displayEnd = selection.period == .year ? calendar.dateInterval(of: .year, for: date)?.end : nil
            result.insights = ReadingInsightsCalculator.calculate(input, statistics: result, calendar: calendar, now: date, displayEnd: displayEnd)
            result.extended = ExtendedStatisticsCalculator.calculate(input, statistics: result, calendar: calendar, now: date)
            return result
        }
        worker = task
        publisher = Task { [weak self] in
            let result = await task.value
            guard let self, !Task.isCancelled, self.calculationID == token,
                  self.library.accountScope?.isActive != false else { return }
            self.statistics = result
            self.isCalculating = false
        }
    }
}
