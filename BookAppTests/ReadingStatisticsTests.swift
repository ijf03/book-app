import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingStatisticsTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var now: Date { date("2026-11-09T12:00:00Z") }
    private func selection(_ from: String, _ to: String) -> StatisticsSelection {
        .init(period: .custom, from: date(from), to: date(to))
    }
    private var all: StatisticsSelection { .init(from: now, to: now) }
    private func calculate(_ input: StatisticsInput, _ period: StatisticsSelection? = nil) -> ReadingStatistics {
        ReadingStatisticsCalculator.calculate(input, selection: period ?? all, calendar: calendar, now: now)
    }
    private func session(start: String = "2026-11-08T10:00:00Z", end: String? = "2026-11-08T11:00:00Z",
                         paused: Int = 0, pages: (Int?, Int?) = (nil, nil), book: String = "book", id: UUID = UUID()) -> StatisticsInput.SessionValue {
        .init(id: id, bookID: book, start: date(start), end: end.map(date), pausedSeconds: paused, startPage: pages.0, endPage: pages.1)
    }

    @Test func emptyDataHasZeroTotalsAndNoInventedRatingOrPages() {
        let stats = calculate(.init())
        #expect(!stats.hasData)
        #expect(stats.completedBooks == 0 && stats.seconds == 0 && stats.sessions == 0)
        #expect(stats.pages == 0 && stats.sessionsWithPages == 0)
        #expect(stats.averageRating == nil)
        #expect(stats.formats.allSatisfy { $0.count == 0 })
    }

    @Test func customDatesIncludeWholeEndDayButExcludeNextMidnightAndFutureData() {
        var input = StatisticsInput()
        input.sessions = [
            session(start: "2026-11-01T00:00:00Z", end: "2026-11-01T01:00:00Z"),
            session(start: "2026-11-02T23:00:00Z", end: "2026-11-02T23:59:59Z"),
            session(start: "2026-11-02T23:00:00Z", end: "2026-11-03T00:00:00Z"),
            session(start: "2026-11-10T00:00:00Z", end: "2026-11-10T01:00:00Z")
        ]
        let stats = calculate(input, selection("2026-11-01T12:00:00Z", "2026-11-02T12:00:00Z"))
        #expect(stats.sessions == 2)
        #expect(stats.seconds == 7199)
        #expect(stats.activity.count == 2)
        #expect(calculate(input).sessions == 3)
    }

    @Test func presetsAndCustomValidationUseCalendarBoundaries() {
        for (period, expected) in [(StatisticsPeriod.month, "2026-11-01T00:00:00Z"), (.quarter, "2026-10-01T00:00:00Z"), (.year, "2026-01-01T00:00:00Z")] {
            let range = StatisticsSelection(period: period, from: now, to: now).interval(calendar: calendar, now: now, earliest: now)
            #expect(range?.start == date(expected))
            #expect(range?.end == date("2026-11-10T00:00:00Z"))
        }
        #expect(selection("2026-11-02T00:00:00Z", "2026-11-01T00:00:00Z").validation(calendar: calendar, now: now) != nil)
        #expect(selection("2026-11-01T00:00:00Z", "2026-11-10T00:00:00Z").validation(calendar: calendar, now: now) != nil)
        #expect(selection("2026-11-09T00:00:00Z", "2026-11-09T23:59:59Z").validation(calendar: calendar, now: now) == nil)
        let leap = selection("2024-02-29T00:00:00Z", "2024-02-29T00:00:00Z").interval(calendar: calendar, now: now, earliest: now)
        #expect(leap?.end == date("2024-03-01T00:00:00Z"))
    }

    @Test func daylightSavingDayIsNotAssumedToBeTwentyFourHours() throws {
        var melbourne = calendar
        melbourne.timeZone = try #require(TimeZone(identifier: "Australia/Melbourne"))
        let range = selection("2026-10-04T02:00:00Z", "2026-10-04T02:00:00Z")
            .interval(calendar: melbourne, now: now, earliest: now)
        #expect(range?.duration == 82800.0)
        let fall = selection("2026-04-05T02:00:00Z", "2026-04-05T02:00:00Z")
            .interval(calendar: melbourne, now: now, earliest: now)
        #expect(fall?.duration == 90000.0)
    }

    @Test func sessionsCrossingBoundariesBelongEntirelyToEndDateAndExcludePauses() {
        var input = StatisticsInput()
        input.sessions = [session(start: "2026-10-31T23:30:00Z", end: "2026-11-01T00:30:00Z", paused: 900),
                          session(end: nil), session(paused: 5000),
                          session(start: "2026-11-08T12:00:00Z", end: "2026-11-08T11:00:00Z")]
        let november = calculate(input, selection("2026-11-01T00:00:00Z", "2026-11-09T00:00:00Z"))
        #expect(november.seconds == 2700)
        #expect(november.sessions == 2)
        #expect(november.activity.reduce(0) { $0 + $1.seconds } == november.seconds)
        #expect(calculate(input, selection("2026-10-31T00:00:00Z", "2026-10-31T00:00:00Z")).seconds == 0)
    }

    @Test func pagesRequireExplicitValidSessionChangesAndDoNotConvertOtherProgress() {
        var book = Book.mockFourthWing
        book.progress = .init(page: 400, percentage: 90, timestampSeconds: 5000)
        let audio = ReadingSession(bookID: book.id, startedAt: date("2026-11-08T10:00:00Z"), endedAt: date("2026-11-08T11:00:00Z"),
                                   startProgress: .init(page: nil, percentage: 20, timestampSeconds: 100),
                                   endProgress: .init(page: nil, percentage: 40, timestampSeconds: 2000))
        var input = StatisticsInput(books: [book], sessions: [audio], reviews: [])
        input.sessions += [session(pages: (nil, 100)), session(pages: (20, nil)), session(pages: (20, 10)), session(pages: (-1, 10)), session(pages: (10, 10))]
        let stats = calculate(input)
        #expect(stats.pages == 0)
        #expect(stats.sessionsWithPages == 1)
    }

    @Test func repeatedAndOverlappingPageSnapshotsOnlyCountNewCoverageAcrossPeriods() {
        var input = StatisticsInput()
        let first = session(start: "2026-10-01T10:00:00Z", end: "2026-10-01T11:00:00Z", pages: (0, 100))
        input.sessions = [first, first,
                          session(start: "2026-11-01T10:00:00Z", end: "2026-11-01T11:00:00Z", pages: (0, 100)),
                          session(start: "2026-11-02T10:00:00Z", end: "2026-11-02T11:00:00Z", pages: (80, 130)),
                          session(start: "2026-11-03T10:00:00Z", end: "2026-11-03T11:00:00Z", pages: (200, 220)),
                          session(pages: (0, 100), book: "another-book")]
        #expect(calculate(input).pages == 250)
        #expect(calculate(input).sessions == 5)
        let month = calculate(input, .init(period: .month, from: now, to: now))
        #expect(month.pages == 150)
        #expect(month.activity.reduce(0) { $0 + $1.pages } == month.pages)
    }

    @Test func completionDatesFormatsAndUndatedLegacyBooksHaveExplicitMeaning() {
        var input = StatisticsInput()
        input.books = [
            .init(id: "physical", completed: true, completedAt: date("2026-11-01T00:00:00Z"), format: "physical"),
            .init(id: "ebook", completed: true, completedAt: date("2026-10-01T00:00:00Z"), format: "ebook"),
            .init(id: "audio", completed: true, completedAt: nil, format: "audiobook"),
            .init(id: "rereading", completed: false, completedAt: date("2026-11-01T00:00:00Z"), format: "physical")]
        let allTime = calculate(input)
        #expect(allTime.completedBooks == 3)
        #expect(allTime.formats.map(\.count) == [1, 1, 1, 0])
        #expect(allTime.undatedCompletedBooks == 1)
        let month = calculate(input, .init(period: .month, from: now, to: now))
        #expect(month.completedBooks == 1)
        #expect(month.formats.map(\.count) == [1, 0, 0, 0])
    }

    @Test func ratingsUseReviewCreationDateAndCurrentRatingNotCompletionOrEditDate() {
        var input = StatisticsInput()
        input.reviews = [
            .init(bookID: "old", rating: 1, createdAt: date("2026-10-01T00:00:00Z"), updatedAt: now),
            .init(bookID: "new", rating: 3, createdAt: date("2026-11-01T00:00:00Z"), updatedAt: date("2026-11-01T00:00:00Z")),
            .init(bookID: "new", rating: 5, createdAt: date("2026-11-01T00:00:00Z"), updatedAt: now),
            .init(bookID: "invalid", rating: 8, createdAt: now, updatedAt: now)]
        #expect(calculate(input).averageRating == 3)
        #expect(calculate(input, .init(period: .month, from: now, to: now)).averageRating == 5)
    }

    @Test func localEditsDownloadsAndAccountRevocationRefreshWithoutLeakingResults() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scope = AccountStorageScope(directory: directory)
        let session = try AccountSession(scope: scope)
        let model = DetailedStatisticsViewModel(library: session.libraryStore, sessions: session.readingSessionStore,
                                                content: session.bookContentStore, calendar: calendar, now: { self.now })
        model.start()
        await settle { !model.isCalculating }
        #expect(!model.statistics.hasData)
        var book = Book.mockFourthWing
        book.status = .completed
        book.completedAt = now
        session.libraryStore.addBook(book)
        await settle { model.statistics.completedBooks == 1 }
        session.bookContentStore.saveReview(.init(bookID: book.id, rating: 4, text: "", createdAt: now, updatedAt: now))
        await settle { model.statistics.averageRating == 4 }
        // Exercise the same local hydration path used by incoming cloud data.
        book.format = .audiobook
        book.language = "French"
        book.bookType = "fiction"
        try LocalLibraryDataSource(scope: scope).saveBooks([book])
        session.libraryStore.reloadFromLocalSync()
        await settle { model.statistics.formats.first { $0.id == "audiobook" }?.count == 1 }
        await settle { model.statistics.extended.languages.first?.name == "French" }
        model.refresh()
        session.invalidate()
        await settle { !model.statistics.hasData && !model.isCalculating }
        model.stop()
        let secondDirectory = directory.appendingPathComponent("B")
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        let b = try AccountSession(scope: .init(directory: secondDirectory))
        let other = DetailedStatisticsViewModel(library: b.libraryStore, sessions: b.readingSessionStore, content: b.bookContentStore)
        other.start()
        await settle { !other.isCalculating }
        #expect(!other.statistics.hasData)
        other.stop()
        b.invalidate()
    }

    private func settle(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }
}
