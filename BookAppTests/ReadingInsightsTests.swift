import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingInsightsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var now: Date { date("2026-11-09T12:00:00Z") }
    private func session(_ day: String, pages: (Int?, Int?) = (nil, nil), paused: Int = 0, book: String = "one") -> StatisticsInput.SessionValue {
        .init(id: UUID(), bookID: book, start: date("\(day)T10:00:00Z"), end: date("\(day)T11:00:00Z"), pausedSeconds: paused, startPage: pages.0, endPage: pages.1)
    }
    private func calculate(_ input: StatisticsInput, period: StatisticsPeriod = .year) -> ReadingInsights {
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(period: period, from: now, to: now), calendar: calendar, now: now)
        return ReadingInsightsCalculator.calculate(input, statistics: stats, calendar: calendar, now: now)
    }

    @Test func paceUsesPausesAndOnlyReliableNewPageCoverage() {
        var input = StatisticsInput()
        input.sessions = [
            session("2026-11-01", pages: (0, 30), paused: 1800),
            session("2026-11-02", pages: (0, 30)),
            session("2026-11-03", pages: (30, 50)),
            session("2026-11-04")
        ]
        let result = calculate(input)
        #expect(result.pagesPerHour == 20) // 50 new pages / 2.5 eligible hours
        #expect(abs((result.pagesPerSession ?? 0) - 50.0 / 3) < 0.0001)
        #expect(result.daysToFinish == nil)
    }

    @Test func streaksCrossMonthsAndCompletionMarkersDoNotInventReading() {
        var input = StatisticsInput()
        input.sessions = [session("2026-10-30"), session("2026-10-31"), session("2026-11-01"),
                          session("2026-11-08"), session("2026-11-09", paused: 3600)]
        input.books = [.init(id: "one", completed: true, completedAt: date("2026-11-09T00:00:00Z"), format: "physical")]
        let result = calculate(input)
        #expect(result.longestStreak == 3)
        #expect(result.currentStreak == 1)
        let november = result.months.last!
        #expect(november.days.first { $0.number == 1 }?.best == true)
        #expect(november.days.first { $0.number == 9 }?.finished == true)
        #expect(november.days.first { $0.number == 9 }?.active == false)
        #expect(result.activeDaysPerMonth == 0.2) // 2 active days / 10 complete months
    }

    @Test func completionsGenresAuthorsAndRatingsUseDocumentedDates() {
        var input = StatisticsInput()
        input.books = [
            .init(id: "one", completed: true, completedAt: date("2026-11-03T12:00:00Z"), format: "physical", title: "One", authors: ["A", "A"], genre: "Fantasy"),
            .init(id: "two", completed: true, completedAt: date("2026-11-04T12:00:00Z"), format: "ebook", title: "Two", authors: ["A", "B"]),
            .init(id: "undated", completed: true, completedAt: nil, format: "ebook", title: "Old", authors: ["C"], genre: "Mystery")
        ]
        input.sessions = [session("2026-11-01")]
        input.reviews = [.init(bookID: "one", rating: 5, createdAt: now, updatedAt: now),
                         .init(bookID: "two", rating: 2, createdAt: date("2025-01-01T00:00:00Z"), updatedAt: now)]
        let result = calculate(input)
        #expect(result.months.last?.books.count == 2)
        #expect(result.genres.first?.name == "Fantasy")
        #expect(result.untaggedBooks == 1)
        #expect(result.authors.first?.count == 2)
        #expect(result.ratings.map(\.count) == [0, 0, 0, 0, 1])
        #expect(result.daysToFinish == 3)
        #expect(result.completionSamples == 1)
    }

    @Test func monthlyRadarIncludesActualPreviousMonthAndEmptyDataIsHonest() {
        var input = StatisticsInput()
        input.sessions = [session("2026-10-01", pages: (0, 10)), session("2026-11-01", pages: (10, 30))]
        let result = calculate(input, period: .month)
        #expect(result.months.count == 1)
        #expect(result.comparisonMonths.count == 2)
        #expect(result.comparisonMonths.map(\.pages) == [10, 20])
        let empty = calculate(.init(), period: .month)
        #expect(empty.pagesPerHour == nil && empty.pagesPerSession == nil)
        #expect(empty.longestStreak == 0)
        #expect(empty.activeDaysPerMonth == nil)
    }

    @Test func goalIdentityPreservesLegacyAndSeparatesFrequenciesAndMetrics() throws {
        let legacy = try JSONDecoder().decode(ReadingGoal.self, from: Data(#"{"year":2026,"target":30}"#.utf8))
        #expect(legacy.id == "2026")
        let annual = InsightGoalModel.goal(period: .year, metric: .books, date: now, target: 30, calendar: calendar)
        #expect(annual.id == legacy.id)
        var ids = Set<String>()
        for period in InsightGoalPeriod.allCases {
            for metric in InsightGoalMetric.allCases {
                let goal = InsightGoalModel.goal(period: period, metric: metric, date: now, target: 30, calendar: calendar)
                #expect(ids.insert(goal.id).inserted)
                let entities = try SyncEntityCodec.entities(file: "reading-goals.json", data: JSONEncoder().encode([goal]))
                #expect(entities.first?.id == goal.id)
                #expect(try JSONDecoder().decode([ReadingGoal].self, from: JSONEncoder().encode([goal])).first == goal)
            }
        }
        let nextMonth = InsightGoalModel.goal(period: .month, metric: .books, date: date("2026-10-09T12:00:00Z"), target: 30, calendar: calendar)
        #expect(nextMonth.id != InsightGoalModel.goal(period: .month, metric: .books, date: now, target: 30, calendar: calendar).id)
    }

    @Test func genreRoundTripDoesNotInventLegacyCompletionDate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let dataSource = LocalLibraryDataSource(scope: AccountStorageScope(directory: directory))
        var book = Book.mockFourthWing
        book.status = .completed
        book.completedAt = nil
        let library = LibraryStore(books: [book], localDataSource: dataSource)
        library.updateGenre(bookID: book.id, genre: "Fantasy")
        #expect(library.books.first?.completedAt == nil)
        #expect(library.books.first?.genre == "Fantasy")
        let encoded = try JSONEncoder().encode(library.books)
        let entities = try SyncEntityCodec.entities(file: "library.json", data: encoded)
        let payload = try #require(entities.first { $0.collection == .books }?.payload)
        #expect(try JSONDecoder().decode(Book.self, from: payload).genre == "Fantasy")
    }
}
