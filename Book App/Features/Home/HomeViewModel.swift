import Foundation
import Observation

@MainActor @Observable
final class HomeViewModel {
    let store: LibraryStore
    let sessionStore: ReadingSessionStore
    let goals: ReadingGoalsViewModel
    private(set) var now = Date()
    private(set) var statistics = ReadingStatistics()
    private(set) var yearlyCompleted = 0
    @ObservationIgnored private var refreshID = UUID()

    init(store: LibraryStore, sessionStore: ReadingSessionStore) {
        self.store = store
        self.sessionStore = sessionStore
        goals = ReadingGoalsViewModel(library: store)
    }

    var currentlyReadingBooks: [Book] { store.books.filter { $0.status == .reading } }
    var upNextBooks: [Book] { store.books.filter { $0.status == .toRead } }
    var completedBooks: [Book] {
        store.books.filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    var readingCount: Int { currentlyReadingBooks.count }
    var toReadCount: Int { upNextBooks.count }
    var completedCount: Int { completedBooks.count }
    var checkIns: ReadingCheckInStore { store.checkIns }
    var refreshKey: String {
        "\(store.books.hashValue)-\(sessionStore.sessions.hashValue)-\(checkIns.entries.hashValue)-\(store.accountScope?.cloudRevision ?? 0)"
    }
    var greeting: LocalizedStringResource {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
    var currentStreak: Int {
        ReadingDayCalculator.currentStreak(
            days: ReadingDayCalculator.days(events: statistics.events, checkIns: checkIns.entries, calendar: .current, now: now),
            calendar: .current, now: now)
    }
    var didReadToday: Bool {
        ReadingDayCalculator.days(events: statistics.events, checkIns: checkIns.entries, calendar: .current, now: now)
            .contains(Calendar.current.startOfDay(for: now))
    }
    var todayAnswer: Bool? {
        checkIns.entries.first { $0.day == ReadingCheckIn.dayKey(now, calendar: .current) }?.didRead
    }
    var hasSessionToday: Bool {
        statistics.events.contains { $0.seconds > 0 && Calendar.current.isDate($0.end, inSameDayAs: now) }
    }
    var todayReadingSeconds: Int {
        statistics.events.filter { Calendar.current.isDate($0.end, inSameDayAs: now) }.reduce(0) { $0 + $1.seconds }
    }
    var todaySessionCount: Int {
        statistics.events.filter { Calendar.current.isDate($0.end, inSameDayAs: now) }.count
    }
    var formattedTodayReadingTime: String {
        Duration.seconds(todayReadingSeconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
    var yearlyTarget: Int? { goals.goal(for: Calendar.current.component(.year, from: now))?.target }

    func checkIn(_ didRead: Bool) {
        now = Date()
        checkIns.setToday(didRead: didRead, now: now)
    }

    func refresh(at date: Date = Date()) async {
        now = date
        goals.reload()
        let token = UUID()
        refreshID = token
        guard store.accountScope?.isActive != false else { statistics = .init(); yearlyCompleted = 0; return }
        let input = StatisticsInput(books: store.books, sessions: sessionStore.sessions, reviews: [], checkIns: checkIns.entries)
        let calendar = Calendar.current
        let task = Task.detached(priority: .userInitiated) {
            let all = ReadingStatisticsCalculator.calculate(input, selection: .init(from: date, to: date), calendar: calendar, now: date)
            let year = ReadingStatisticsCalculator.calculate(input, selection: .init(period: .year, from: date, to: date), calendar: calendar, now: date)
            return (all, year.completedBooks)
        }
        let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard !Task.isCancelled, token == refreshID, store.accountScope?.isActive != false else { return }
        statistics = result.0
        yearlyCompleted = result.1
    }

    func updateBook(_ book: Book) { store.updateBook(book) }
    func removeBook(id: String) { store.removeBook(id: id) }
}
