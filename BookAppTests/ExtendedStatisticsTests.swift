import Foundation
import Testing
@testable import Book_App

@MainActor
struct ExtendedStatisticsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func calculate(_ input: StatisticsInput) -> ExtendedReadingStatistics {
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now)
        return ExtendedStatisticsCalculator.calculate(input, statistics: stats, calendar: calendar, now: now)
    }

    @Test func emptyAndUnknownMetadataAreNotInvented() {
        #expect(calculate(.init()).books.isEmpty)
        #expect(calculate(.init()).averageFinishSeconds == nil)
        var input = StatisticsInput()
        input.books = [.init(id: "one", completed: true, completedAt: now, format: "physical", title: "One")]
        let result = calculate(input)
        #expect(result.types.first?.name == "Not recorded")
        #expect(result.languages.first?.count == 1)
        #expect(result.moods.first?.name == "Not recorded")
        #expect(result.books.first?.pace == nil)
        #expect(result.books.first?.pages == nil)
        #expect(result.topBooks.isEmpty)
    }

    @Test func comparisonSubtractsPausesDeduplicatesPagesAndExcludesUnfinishedSessions() {
        var input = StatisticsInput()
        input.books = [.init(id: "one", completed: true, completedAt: now, format: "immersive")]
        input.sessions = [
            .init(id: UUID(), bookID: "one", start: now.addingTimeInterval(-10800), end: now.addingTimeInterval(-7200), pausedSeconds: 1800, startPage: 0, endPage: 30),
            .init(id: UUID(), bookID: "one", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), pausedSeconds: 0, startPage: 0, endPage: 30),
            .init(id: UUID(), bookID: "one", start: now.addingTimeInterval(-3600), end: nil, pausedSeconds: 0, startPage: 30, endPage: 100)
        ]
        let result = calculate(input)
        #expect(result.books.first?.pages == 30)
        #expect(result.books.first?.seconds == 5400)
        #expect(result.books.first?.pace == 20)
        #expect(result.books.first?.sessions == 2)
        #expect(result.averageFinishSeconds == 5400)
        #expect(result.finishSamples == 1)
    }

    @Test func completionTimeExcludesSessionsAfterFinishingAndRatingsUseCreationDate() {
        let end = calendar.startOfDay(for: now)
        var input = StatisticsInput()
        input.books = [.init(id: "one", completed: true, completedAt: end, format: "ebook", title: "One", bookType: "fiction", language: " english ")]
        input.sessions = [
            .init(id: UUID(), bookID: "one", start: end.addingTimeInterval(-3600), end: end, pausedSeconds: 0, startPage: 0, endPage: 20),
            .init(id: UUID(), bookID: "one", start: end, end: end.addingTimeInterval(60), pausedSeconds: 0, startPage: 20, endPage: 21)
        ]
        input.reviews = [.init(bookID: "one", rating: 5, createdAt: end.addingTimeInterval(-86400), updatedAt: now, mood: "hopeful")]
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(period: .custom, from: end, to: end), calendar: calendar, now: now)
        let result = ExtendedStatisticsCalculator.calculate(input, statistics: stats, calendar: calendar, now: now)
        #expect(result.books.first?.finishSeconds == 3600)
        #expect(result.books.first?.daysToFinish == 2)
        #expect(result.ratingsByType.isEmpty)
        #expect(result.topBooks.first?.rating == 5)
        #expect(result.moods.first?.name == "Hopeful")
        #expect(result.languages.first?.name == "English")
        #expect(result.types.first?.name == "Fiction")
    }

    @Test func duplicateReviewsAndDeletedBookMetadataDoNotDoubleCount() {
        var input = StatisticsInput()
        input.reviews = [
            .init(bookID: "deleted", rating: 2, createdAt: now, updatedAt: now.addingTimeInterval(-1)),
            .init(bookID: "deleted", rating: 4, createdAt: now, updatedAt: now)
        ]
        let result = calculate(input)
        #expect(result.ratingsByType.first?.ratings.map(\.count) == [0, 0, 0, 1, 0])
        #expect(result.ratingsByFormat.first?.name == "Not recorded")
    }

    @Test func newMetadataRoundTripsAndLegacyDocumentsDecode() throws {
        var book = Book.mockFourthWing
        book.genre = "Fantasy"
        book.bookType = "fiction"
        book.language = "English"
        book.format = .immersive
        let encoded = try JSONEncoder().encode(book)
        #expect(try JSONDecoder().decode(Book.self, from: encoded) == book)
        let review = BookReview(bookID: book.id, rating: 5, text: "", mood: "Hopeful")
        #expect(try JSONDecoder().decode(BookReview.self, from: JSONEncoder().encode(review)).mood == "Hopeful")
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "bookType")
        legacy.removeValue(forKey: "language")
        legacy["format"] = "physical"
        let decoded = try JSONDecoder().decode(Book.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.bookType == nil && decoded.language == nil)
        var legacyReview = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(review)) as? [String: Any])
        legacyReview.removeValue(forKey: "mood")
        #expect(try JSONDecoder().decode(BookReview.self, from: JSONSerialization.data(withJSONObject: legacyReview)).mood == nil)
        let entities = try SyncEntityCodec.entities(file: "library.json", data: JSONEncoder().encode([book]))
        let payload = try #require(entities.first { $0.collection == .books }?.payload)
        #expect(try JSONDecoder().decode(Book.self, from: payload).format == .immersive)
    }

    @Test func metadataEditsPreserveUndatedCompletionAndRevokedAccountCannotSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let source = LocalLibraryDataSource(scope: scope)
        var book = Book.mockFourthWing
        book.status = .completed
        book.completedAt = nil
        let store = LibraryStore(books: [book], localDataSource: source)
        book.language = "English"
        store.updateBook(book)
        #expect(store.books.first?.completedAt == nil)
        #expect(try source.loadBooks()?.first?.language == "English")
        scope.invalidate()
        book.language = "French"
        store.updateBook(book)
        #expect(store.books.first?.language == "English")
        #expect(store.persistenceError != nil)
    }

    @Test func shareRendererProducesPNGWithoutDummyStats() throws {
        let model = StatisticsShareModel()
        model.render(ReadingStatistics())
        let bytes = try #require(model.export?.png)
        #expect(Array(bytes.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        #expect(model.image != nil)
        #expect(!model.failed)
    }
}
