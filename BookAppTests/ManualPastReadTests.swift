import Foundation
import Testing
@testable import Book_App

@MainActor
struct ManualPastReadTests {
    @Test func validatesKnownDatesAndAllowsEveryUnknownCombination() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        #expect(PastRead.validation(start: nil, end: nil, now: now) == nil)
        #expect(PastRead.validation(start: yesterday, end: nil, now: now) == nil)
        #expect(PastRead.validation(start: nil, end: yesterday, now: now) == nil)
        #expect(PastRead.validation(start: yesterday, end: yesterday, now: now) == nil)
        #expect(PastRead.validation(start: now, end: yesterday, now: now) != nil)
        #expect(PastRead.validation(start: nil, end: now.addingTimeInterval(86400), now: now) != nil)
    }

    @Test func savesUnknownDatesWithoutChangingCurrentReadOrInventingSessionData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let source = LocalLibraryDataSource(scope: scope)
        let book = Book(id: "manual", title: "Book", authors: [], status: .reading, format: .ebook,
                        progress: .init(page: 50))
        let library = LibraryStore(books: [book], localDataSource: source)
        let model = AddPastReadViewModel()
        model.startUnknown = true
        model.endUnknown = true
        #expect(model.save(bookID: book.id, library: library))
        #expect(model.save(bookID: book.id, library: library))
        let saved = try #require(source.loadBooks()?.first)
        #expect(saved.pastReads?.count == 1)
        #expect(saved.pastReads?.first?.startedAt == nil && saved.pastReads?.first?.completedAt == nil)
        #expect(saved.progress == book.progress && saved.status == book.status && saved.currentReadID == book.currentReadID)
        let now = Date()
        let input = StatisticsInput(books: [saved], sessions: [], reviews: [])
        let all = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: .current, now: now)
        #expect(all.completedBooks == 1 && all.pages == 0 && all.seconds == 0)
        let month = ReadingStatisticsCalculator.calculate(input, selection: .init(period: .month, from: now, to: now), calendar: .current, now: now)
        #expect(month.completedBooks == 0)
        scope.invalidate()
        let another = AddPastReadViewModel()
        #expect(!another.save(bookID: book.id, library: library))
        #expect(library.book(id: book.id)?.pastReads?.count == 1)
    }
}
