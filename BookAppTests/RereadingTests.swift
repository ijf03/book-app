import Foundation
import Testing
@testable import Book_App

@MainActor
struct RereadingTests {
    private let end = Date(timeIntervalSince1970: 1_700_000_000)
    private func book() -> Book {
        Book(id: "/works/example", title: "A book", authors: ["An author"], pageCount: 100,
             status: .completed, format: .physical, completedAt: end,
             progress: .init(page: 100, percentage: 100, timestampSeconds: 3600))
    }

    @Test func resetsAllProgressAndArchivesExactlyOnce() throws {
        var value = book()
        value.beginReread(at: end.addingTimeInterval(86400))
        #expect(value.status == .reading && value.completedAt == nil)
        #expect(value.progress == ReadingProgress(page: 0, percentage: 0, timestampSeconds: 0))
        #expect(value.pastReads?.first?.completedAt == end)
        #expect(value.pastReads?.first?.progress.page == 100)
        let cycle = value.currentReadID
        value.beginReread()
        #expect(value.pastReads?.count == 1 && value.currentReadID == cycle)
        #expect(try JSONDecoder().decode(Book.self, from: JSONEncoder().encode(value)) == value)
        value.status = .completed
        value.completedAt = end.addingTimeInterval(172800)
        value.beginReread(at: end.addingTimeInterval(259200))
        #expect(value.pastReads?.count == 2 && value.currentReadID != cycle)
    }

    @Test func preservesCompletionTimeAndCountsPagesAgainOnlyInNewCycle() {
        var value = book()
        let old = ReadingSession(bookID: value.id, startedAt: end.addingTimeInterval(-3600),
                                 endedAt: end, totalPausedSeconds: 600,
                                 startProgress: .init(page: 0), endProgress: .init(page: 100))
        value.beginReread(at: end.addingTimeInterval(86400))
        let secondEnd = end.addingTimeInterval(90000)
        let fresh = ReadingSession(bookID: value.id, startedAt: end.addingTimeInterval(86400),
                                   endedAt: secondEnd, startProgress: .init(page: 0),
                                   endProgress: .init(page: 100), readID: value.currentReadID)
        let repeated = ReadingSession(bookID: value.id, startedAt: secondEnd,
                                      endedAt: secondEnd.addingTimeInterval(60),
                                      startProgress: .init(page: 0), endProgress: .init(page: 100),
                                      readID: value.currentReadID)
        value.status = .completed
        value.completedAt = secondEnd
        let now = secondEnd.addingTimeInterval(120)
        let input = StatisticsInput(books: [value], sessions: [old, fresh, repeated], reviews: [])
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: .current, now: now)
        #expect(stats.completedBooks == 2 && stats.pages == 200 && stats.seconds == 6660)
        let insights = ReadingInsightsCalculator.calculate(input, statistics: stats, calendar: .current, now: now)
        #expect(insights.months.flatMap(\.books).count == 2)
        #expect(Set(insights.months.flatMap(\.books).map(\.id)).count == 2)
        let extended = ExtendedStatisticsCalculator.calculate(input, statistics: stats, calendar: .current, now: now)
        #expect(extended.finishSamples == 2 && extended.averageFinishSeconds == 3300)
        let earlier = ReadingStatisticsCalculator.calculate(input, selection: .init(period: .custom, from: end, to: end), calendar: .current, now: now)
        #expect(earlier.completedBooks == 1 && earlier.pages == 100)
    }

    @Test func oldOngoingSessionIsNotResumedAndStaleEditsCannotUndoReread() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let oldBook = book()
        let library = LibraryStore(books: [oldBook], localDataSource: LocalLibraryDataSource(scope: scope))
        let oldSession = ReadingSession(bookID: oldBook.id, startProgress: oldBook.progress)
        let sessions = ReadingSessionStore(sessions: [oldSession], localDataSource: LocalReadingSessionDataSource(scope: scope))
        var draft = oldBook
        draft.status = .reading
        library.updateBook(draft)
        let reread = try #require(library.book(id: oldBook.id))
        let newSession = sessions.startSession(for: reread)
        #expect(newSession.id != oldSession.id && newSession.readID == reread.currentReadID)
        #expect(newSession.startProgress.page == 0 && sessions.sessions.count == 2)
        library.updateBook(oldBook)
        #expect(library.book(id: oldBook.id) == reread)
        scope.invalidate()
        var completed = reread
        completed.status = .completed
        library.updateBook(completed)
        #expect(library.book(id: oldBook.id) == reread)
    }

    @Test func legacyUnknownDatesRemainUnknownAndHistoryUsesRecordedSessionStart() throws {
        var value = book()
        value.completedAt = nil
        let legacy = try JSONDecoder().decode(Book.self, from: JSONEncoder().encode(value))
        #expect(legacy.currentReadID == nil && legacy.pastReads == nil)
        value.beginReread()
        #expect(value.pastReads?.first?.completedAt == nil)
        #expect(PastReadsPresentation.rows(book: value, sessions: []).first?.dates.contains("not recorded") == true)
        var dated = book()
        dated.beginReread()
        let session = ReadingSession(bookID: dated.id, startedAt: end.addingTimeInterval(-86400),
                                     endedAt: end, startProgress: .empty)
        let rows = PastReadsPresentation.rows(book: dated, sessions: [session])
        #expect(rows.count == 1 && rows[0].usesSessionStart)
    }

    @Test func rereadHistoryAndSessionIDsSurviveOfflineJournalAndRemoteProjection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root.appendingPathComponent("one"))
        let local = try LocalSyncRepository(userID: "A", scope: scope)
        scope.syncRepository = local
        var value = book()
        value.beginReread()
        try LocalLibraryDataSource(scope: scope).saveBooks([value])
        let session = ReadingSession(bookID: value.id, startProgress: value.progress, readID: value.currentReadID)
        try LocalReadingSessionDataSource(scope: scope).saveSessions([session])
        let reopened = try LocalSyncRepository(userID: "A", scope: scope)
        #expect(!reopened.pending.isEmpty)
        let otherScope = AccountStorageScope(directory: root.appendingPathComponent("two"))
        let other = try LocalSyncRepository(userID: "A", scope: otherScope)
        otherScope.syncRepository = other
        try other.receive(reopened.records)
        #expect(try LocalLibraryDataSource(scope: otherScope).loadBooks()?.first == value)
        #expect(try LocalReadingSessionDataSource(scope: otherScope).loadSessions().first == session)
        let bScope = AccountStorageScope(directory: root.appendingPathComponent("B"))
        #expect(try LocalLibraryDataSource(scope: bScope).loadBooks() == nil)
    }
}
