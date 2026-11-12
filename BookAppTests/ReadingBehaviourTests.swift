import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingBehaviourTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func book(_ id: String, status: String = "completed", genre: String? = "Mystery",
                      pages: Int? = 250, days: Int = 4, ago: Int = 1) -> StatisticsInput.BookValue {
        .init(id: id, completed: status == "completed",
              completedAt: status == "completed" ? now.addingTimeInterval(-Double(ago) * 86400) : nil,
              format: "physical", genre: genre,
              startedAt: now.addingTimeInterval(-Double(ago + days - 1) * 86400),
              status: status, pageCount: pages)
    }

    @Test func formatsNormalizeToTheSamePositionWithoutInventingMissingTotals() {
        let physical = ReadingProgress(page: 240, percentage: nil, timestampSeconds: nil)
        let ebook = ReadingProgress(page: nil, percentage: 50, timestampSeconds: nil)
        let audio = ReadingProgress(page: nil, percentage: nil, timestampSeconds: 18000)
        #expect(physical.normalizedFraction(pageCount: 480, audioDuration: nil) == 0.5)
        #expect(ebook.normalizedFraction(pageCount: nil, audioDuration: nil) == 0.5)
        #expect(audio.normalizedFraction(pageCount: nil, audioDuration: 36000) == 0.5)
        #expect(audio.normalizedFraction(pageCount: nil, audioDuration: nil) == nil)
        #expect(physical.normalizedFraction(pageCount: nil, audioDuration: nil) == nil)
        #expect(ReadingProgress.parseTime("05:00:00") == 18000)
        #expect(ReadingProgress.parseTime("00:60:00") == nil)
        #expect(ReadingProgress.parseTime("-1:00:00") == nil)
    }

    @Test func switchingFormatsKeepsSharedProgressAndAudioDoesNotInventPages() throws {
        var source = Book.mockFourthWing
        source.pageCount = 480
        source.audioDurationSeconds = 36000
        source.progress = .init(page: 240, percentage: 50, timestampSeconds: nil)
        let model = UpdateProgressViewModel(book: source)
        #expect(model.unit == .page)
        model.format = .audiobook
        model.changeUnit(.timestamp)
        #expect(model.timestampText == "05:00:00")
        let updated = try #require(model.makeUpdatedBook())
        #expect(updated.progress.percentage == 50)
        #expect(updated.progress.timestampSeconds == 18000)
        #expect(updated.progress.page == nil)
        #expect(updated.currentReadID == source.currentReadID)
        model.timestampText = "11:00:00"
        #expect(!model.canSave)
    }

    @Test func percentageValidationAndEmptySessionPreserveExistingData() throws {
        var source = Book.mockFourthWing
        source.progress = .empty
        source.format = .ebook
        let model = UpdateProgressViewModel(book: source)
        #expect(model.makeUpdatedBook(allowEmptyProgress: true)?.progress == source.progress)
        model.changeUnit(.percentage)
        model.percentageText = "nan"
        #expect(!model.canSave)
        model.percentageText = "101"
        #expect(!model.canSave)
        model.percentageText = "100"
        #expect(try #require(model.makeUpdatedBook()).status == .completed)
    }

    @Test func staleLegacyPageCannotOverrideSharedPercentage() throws {
        var source = Book.mockFourthWing
        source.pageCount = 400
        source.format = .physical
        source.progress = .init(page: 10, percentage: 50, timestampSeconds: nil)
        let model = UpdateProgressViewModel(book: source)
        #expect(model.unit == .page)
        #expect(model.pageText == "200")
        #expect(try #require(model.makeUpdatedBook()).progress.percentage == 50)
    }

    @Test func formatSelectsFieldsAndSavedTotalsReturnOnReopen() throws {
        var source = Book.mockFourthWing
        source.format = .physical
        source.pageCount = nil
        source.progress = .empty
        let model = UpdateProgressViewModel(book: source)
        #expect(model.unit == .page && !model.offersEbookUnits)
        model.pageText = "120"
        #expect(!model.canSave)
        model.pageCountText = "480"
        let saved = try #require(model.makeUpdatedBook())
        let reopened = UpdateProgressViewModel(book: try JSONDecoder().decode(Book.self, from: JSONEncoder().encode(saved)))
        #expect(reopened.pageCountText == "480" && reopened.pageText == "120")
        reopened.format = .audiobook
        #expect(reopened.unit == .timestamp && reopened.usesAudio)
        reopened.audioDurationText = "10:00:00"
        reopened.timestampText = "02:30:00"
        let audio = try #require(reopened.makeUpdatedBook())
        let audioForm = UpdateProgressViewModel(book: audio)
        #expect(audioForm.audioDurationText == "10:00:00")
        #expect(audioForm.timestampText == "02:30:00" && audioForm.unit == .timestamp)
        #expect(audio.pageCount == 480 && audio.progress.percentage == 25)
        audioForm.format = .ebook
        #expect(audioForm.offersEbookUnits && audioForm.unit == .percentage)
        audioForm.changeUnit(.page)
        #expect(audioForm.pageText == "120" && audioForm.pageCountText == "480")
    }

    @Test func immersiveRestoresBothPositionsAndCompanionWithoutDoubleCounting() throws {
        var source = Book.mockFourthWing
        source.format = .immersive
        source.pageCount = 400
        source.progress = .empty
        let model = UpdateProgressViewModel(book: source)
        model.pageText = "120"
        model.audioDurationText = "10:00:00"
        model.timestampText = "04:00:00"
        let physical = try #require(model.makeUpdatedBook())
        #expect(physical.progress.page == 120 && physical.progress.timestampSeconds == 14400)
        #expect(physical.progress.percentage == 40)
        let restored = UpdateProgressViewModel(book: physical)
        #expect(restored.pageText == "120" && restored.timestampText == "04:00:00")
        restored.immersiveCompanion = .ebook
        restored.changeUnit(.percentage)
        restored.percentageText = "35"
        let ebook = try #require(restored.makeUpdatedBook())
        let decoded = try JSONDecoder().decode(Book.self, from: JSONEncoder().encode(ebook))
        let reopened = UpdateProgressViewModel(book: decoded)
        #expect(reopened.immersiveCompanion == .ebook && reopened.unit == .percentage)
        #expect(reopened.percentageText == "35.0" && reopened.timestampText == "04:00:00")
        #expect(decoded.progress.percentage == 40 && decoded.progress.page == nil)
        reopened.timestampText = "11:00:00"
        #expect(!reopened.canSave)
    }

    @Test func outcomesIgnoreUnreadBooksAndUnknownValuesAreNotZero() {
        var input = StatisticsInput()
        input.books = [book("one"), book("two", pages: 400),
                       book("stopped", status: "abandoned", pages: 700),
                       book("unread", status: "toRead", genre: "Fantasy", pages: 1000),
                       book("reading", status: "reading", genre: nil, pages: nil)]
        input.books[2].progressPercentage = 30
        input.books[4].progressPercentage = 50
        input.reviews = [.init(bookID: "one", rating: 5, createdAt: now, updatedAt: now)]
        let profile = ReadingBehaviourCalculator.calculate(input, now: now)
        #expect(profile.completed == 2 && profile.abandoned == 1)
        #expect(profile.medianFinishedPages == 325 && profile.lengthSamples == 2)
        #expect(profile.averageProgress == 50 && profile.progressSamples == 1)
        #expect(profile.averageAbandonedProgress == 30)
        #expect(profile.averageCompletedRating == 5 && profile.ratingSamples == 1)
        #expect(profile.genres.count == 1)
        #expect(profile.genres.first?.completionRate == 2.0 / 3.0)
        #expect(profile.missingGenres == 1 && profile.missingLengths == 1)
        #expect(profile.summary.contains("Mystery"))
    }

    @Test func rereadsAddTimingSamplesButDoNotDoubleCountTitlePreferences() {
        var input = StatisticsInput()
        input.books = [book("one")]
        var reread = book("one", days: 8, ago: 20)
        reread.readID = "earlier"
        input.archivedReads = [reread, reread]
        let profile = ReadingBehaviourCalculator.calculate(input, now: now)
        #expect(profile.completed == 1 && profile.lengthSamples == 1)
        #expect(profile.durationSamples == 2 && profile.averageDays == 6)
        #expect(profile.genres.first?.completed == 1)
        #expect(profile.formats.first?.completions == 2)
    }

    @Test func sparseHistoryDoesNotClaimPreferencesOrCompletionSpeed() {
        var input = StatisticsInput()
        input.books = [.init(id: "one", completed: true, completedAt: nil, format: "physical", status: "completed")]
        let profile = ReadingBehaviourCalculator.calculate(input, now: now)
        #expect(profile.insights.isEmpty)
        #expect(profile.averageDays == nil && profile.durationSamples == 0)
        #expect(profile.medianFinishedPages == nil)
        #expect(profile.undatedCompletions == 1)
        #expect(profile.recentGenre == nil)
    }

    @Test func recentGenresCompareTwoPeriodsAndLengthOutcomesAffectRanking() {
        var input = StatisticsInput()
        input.books = (0..<3).map { book("recent\($0)", genre: "Mystery", ago: 5 + $0) }
            + (0..<3).map { book("prior\($0)", genre: "Fantasy", ago: 40 + $0) }
            + (0..<3).map { book("stopped\($0)", status: "abandoned", genre: "Fantasy", pages: 800) }
        let profile = ReadingBehaviourCalculator.calculate(input, now: now)
        #expect(profile.recentGenre == "Mystery")
        #expect(profile.match(genres: ["Mystery"], pages: 250).score >
                profile.match(genres: ["Fantasy"], pages: 800).score)
        #expect(!profile.match(genres: ["Mystery"], pages: 250).reasons.isEmpty)
        #expect(profile.insights.contains { $0.contains("did not finish") })
    }

    @Test func sessionFormatsAreRecordedWithoutGuessingLegacySessions() {
        var input = StatisticsInput()
        input.books = [book("one")]
        var session = StatisticsInput.SessionValue(id: UUID(), bookID: "one",
            start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600),
            pausedSeconds: 0, startPage: nil, endPage: nil, formats: ["physical", "audiobook"])
        input.sessions = [session, session]
        session = .init(id: UUID(), bookID: "one", start: now.addingTimeInterval(-10800),
                        end: now.addingTimeInterval(-7200), pausedSeconds: 0, startPage: nil, endPage: nil)
        input.sessions.append(session)
        let profile = ReadingBehaviourCalculator.calculate(input, now: now)
        #expect(profile.formats.first { $0.id == "physical" }?.sessions == 1)
        #expect(profile.formats.first { $0.id == "audiobook" }?.sessions == 1)
    }

    @Test func editionChangesAndStoppedReadsPreserveJourneyAndSync() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root)
        let journal = try LocalSyncRepository(userID: "reader", scope: scope)
        scope.syncRepository = journal
        let library = LibraryStore(books: [], localDataSource: .init(scope: scope))
        var source = Book(id: "/works/OL1W", title: "Book", authors: [], pageCount: 480, status: .reading, format: .physical)
        source.progress = .init(page: 240, percentage: nil, timestampSeconds: nil)
        source.audioDurationSeconds = 36000
        #expect(library.addBook(source))
        var result = BookSearchResult(book: source)
        result.metadata = .init(workID: source.id, edition: .init(id: "/books/OL1M", title: "Edition", pages: 600), fetchedAt: now)
        library.applyMetadata(result, bookID: source.id, selectingEdition: true)
        var stopped = try #require(library.books.first)
        #expect(stopped.progress.percentage == 50 && stopped.progress.page == nil)
        let startedAt = stopped.currentReadStartedAt
        stopped.status = .abandoned
        stopped.format = .audiobook
        library.updateBook(stopped)
        #expect(library.books.first?.abandonedAt != nil)
        let second = AccountStorageScope(directory: root.appendingPathComponent("second"))
        let remote = try LocalSyncRepository(userID: "reader", scope: second)
        second.syncRepository = remote
        try remote.receive(journal.records)
        let restored = try #require(try LocalLibraryDataSource(scope: second).loadBooks()?.first)
        #expect(restored.status == .abandoned && restored.audioDurationSeconds == 36000)
        #expect(restored.formatsUsed == [.physical, .audiobook])
        stopped = restored
        stopped.status = .reading
        library.updateBook(stopped)
        #expect(library.books.first?.currentReadStartedAt == startedAt)
        #expect(library.books.first?.progress.percentage == 50)
        #expect(library.books.first?.abandonedAt == nil)
    }

    @Test func optionalNewFieldsKeepLegacyBookDecodingCompatible() throws {
        var source = Book.mockFourthWing
        source.audioDurationSeconds = nil
        source.abandonedAt = nil
        source.formatsUsed = nil
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded == source)
        source.audioDurationSeconds = 36000
        source.abandonedAt = now
        source.status = .abandoned
        source.formatsUsed = [.physical, .audiobook]
        #expect(try JSONDecoder().decode(Book.self, from: JSONEncoder().encode(source)) == source)
    }
}
