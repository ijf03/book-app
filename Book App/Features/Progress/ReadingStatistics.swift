import Foundation

nonisolated enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case allTime, month, quarter, year, custom
    var id: Self { self }
    var title: LocalizedStringResource {
        switch self {
        case .allTime: "All time"
        case .month: "This month"
        case .quarter: "This quarter"
        case .year: "This year"
        case .custom: "Custom dates"
        }
    }
}

nonisolated struct StatisticsSelection: Equatable, Sendable {
    var period: StatisticsPeriod = .allTime
    var from: Date
    var to: Date

    func validation(calendar: Calendar, now: Date) -> LocalizedStringResource? {
        guard period == .custom else { return nil }
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        if start > end { return "From must be on or before To." }
        if start > calendar.startOfDay(for: now) || end > calendar.startOfDay(for: now) {
            return "Choose dates on or before today."
        }
        return nil
    }

    func interval(calendar: Calendar, now: Date, earliest: Date) -> DateInterval? {
        guard validation(calendar: calendar, now: now) == nil,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
        let start: Date
        var end = tomorrow
        switch period {
        case .allTime: start = calendar.startOfDay(for: min(earliest, now))
        case .month: start = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        case .quarter: start = calendar.dateInterval(of: .quarter, for: now)?.start ?? calendar.startOfDay(for: now)
        case .year: start = calendar.dateInterval(of: .year, for: now)?.start ?? calendar.startOfDay(for: now)
        case .custom:
            start = calendar.startOfDay(for: from)
            guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) else { return nil }
            end = next
        }
        return DateInterval(start: start, end: end)
    }
}

/// Sendable value snapshots keep store access on the main actor and calculation off it.
nonisolated struct StatisticsInput: Sendable {
    struct BookValue: Sendable {
        let id: String
        let completed: Bool
        let completedAt: Date?
        let format: String
        var title: String = ""
        var authors: [String] = []
        var coverURL: URL? = nil
        var genre: String? = nil
        var bookType: String? = nil
        var language: String? = nil
        var readID: String? = nil
        var startedAt: Date? = nil
        var cycleKey: String { "\(id.utf8.count):\(id):\(readID ?? "initial")" }
    }
    struct SessionValue: Sendable {
        let id: UUID
        let bookID: String
        let start: Date
        let end: Date?
        let pausedSeconds: Int
        let startPage: Int?
        let endPage: Int?
        var readID: String? = nil
        var cycleKey: String { "\(bookID.utf8.count):\(bookID):\(readID ?? "initial")" }
    }
    struct ReviewValue: Sendable {
        let bookID: String
        let rating: Int
        let createdAt: Date
        let updatedAt: Date
        var mood: String? = nil
    }
    var books: [BookValue] = []
    var archivedReads: [BookValue] = []
    var completedReads: [BookValue] { books.filter(\.completed) + archivedReads }
    var sessions: [SessionValue] = []
    var reviews: [ReviewValue] = []
    var checkIns: [ReadingCheckIn] = []

    @MainActor init(books: [Book], sessions: [ReadingSession], reviews: [BookReview], checkIns: [ReadingCheckIn] = []) {
        self.checkIns = checkIns
        self.books = books.map { .init(id: $0.id, completed: $0.status == .completed, completedAt: $0.completedAt, format: $0.format.rawValue, title: $0.title, authors: $0.authors, coverURL: $0.coverURL, genre: $0.genre, bookType: $0.bookType, language: $0.language, readID: $0.currentReadID, startedAt: $0.currentReadStartedAt) }
        self.archivedReads = books.flatMap { book in
            (book.pastReads ?? []).map { read in
                .init(id: book.id, completed: true, completedAt: read.completedAt, format: read.format.rawValue, title: book.title, authors: book.authors, coverURL: book.coverURL, genre: book.genre, bookType: book.bookType, language: book.language, readID: read.id, startedAt: read.startedAt)
            }
        }
        self.sessions = sessions.map { .init(id: $0.id, bookID: $0.bookID, start: $0.startedAt, end: $0.endedAt,
                                            pausedSeconds: $0.totalPausedSeconds, startPage: $0.startProgress.page, endPage: $0.endProgress?.page, readID: $0.readID) }
        self.reviews = reviews.map { .init(bookID: $0.bookID, rating: $0.rating, createdAt: $0.createdAt, updatedAt: $0.updatedAt, mood: $0.mood) }
    }
    init() {}
}

nonisolated struct ReadingStatistics: Sendable {
    enum Bucket: Sendable {
        case day, week, month, year
        var component: Calendar.Component {
            switch self { case .day: .day; case .week: .weekOfYear; case .month: .month; case .year: .year }
        }
        var title: LocalizedStringResource {
            switch self { case .day: "Daily activity"; case .week: "Weekly activity"; case .month: "Monthly activity"; case .year: "Yearly activity" }
        }
    }
    struct Activity: Identifiable, Sendable {
        var id: Date { start }
        let start: Date
        let end: Date
        var seconds: Int = 0
        var sessions: Int = 0
        var pages: Int = 0
        var books: Int = 0
    }
    struct FormatCount: Identifiable, Sendable {
        let id: String
        var count: Int
        var title: LocalizedStringResource {
            switch id { case "physical": "Physical"; case "ebook": "Ebook"; case "immersive": "Immersive reading"; default: "Audiobook" }
        }
    }
    struct SessionEvent: Sendable {
        let id: UUID
        let bookID: String
        let start: Date
        let end: Date
        let seconds: Int
        let pages: Int?
        var readID: String? = nil
        var cycleKey: String { "\(bookID.utf8.count):\(bookID):\(readID ?? "initial")" }
    }
    var activeDays: Set<Date> = []
    var events: [SessionEvent] = []
    var insights = ReadingInsights()
    var extended = ExtendedReadingStatistics()
    var completedBooks = 0
    var undatedCompletedBooks = 0
    var seconds = 0
    var sessions = 0
    var pages = 0
    var sessionsWithPages = 0
    var ratingCount = 0
    var averageRating: Double?
    var formats: [FormatCount] = [ .init(id: "physical", count: 0), .init(id: "ebook", count: 0), .init(id: "audiobook", count: 0), .init(id: "immersive", count: 0) ]
    var activity: [Activity] = []
    var bucket: Bucket = .day
    var interval: DateInterval?
    var hasData: Bool { completedBooks > 0 || sessions > 0 || ratingCount > 0 || !activeDays.isEmpty }
}

nonisolated enum ReadingStatisticsCalculator {
    static func calculate(_ input: StatisticsInput, selection: StatisticsSelection, calendar: Calendar, now: Date) -> ReadingStatistics {
        var result = ReadingStatistics()
        let dated = input.completedReads.compactMap(\.completedAt) + input.sessions.compactMap(\.end) + input.reviews.map(\.createdAt) + input.checkIns.compactMap { $0.date(calendar: calendar) }
        guard let interval = selection.interval(calendar: calendar, now: now, earliest: dated.filter { $0 <= now }.min() ?? now) else { return result }
        result.interval = interval
        func contains(_ date: Date) -> Bool { date >= interval.start && date < interval.end && date <= now }
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
        result.bucket = days <= 62 ? .day : days <= 366 ? .week : days <= 3653 ? .month : .year
        let component = result.bucket.component
        var bucketIndex: [Date: Int] = [:]
        var cursor = calendar.dateInterval(of: component, for: interval.start)?.start ?? interval.start
        // Calendar arithmetic preserves DST and variable month/year lengths.
        while cursor < interval.end, result.activity.count < 10000 {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            bucketIndex[cursor] = result.activity.count
            result.activity.append(.init(start: max(cursor, interval.start), end: min(next, interval.end)))
            cursor = next
        }
        func index(_ date: Date) -> Int? { bucketIndex[calendar.dateInterval(of: component, for: date)?.start ?? date] }

        var bookIDs = Set<String>()
        for book in input.completedReads where bookIDs.insert(book.cycleKey).inserted {
            if book.completedAt == nil { result.undatedCompletedBooks += 1 }
            guard book.completedAt.map(contains) ?? (selection.period == .allTime) else { continue }
            result.completedBooks += 1
            if let i = result.formats.firstIndex(where: { $0.id == book.format }) { result.formats[i].count += 1 }
            if let date = book.completedAt, let i = index(date) { result.activity[i].books += 1 }
        }

        var sessionIDs = Set<UUID>()
        var pageRanges: [String: [Range<Int>]] = [:]
        let sessions = input.sessions.sorted {
            let left = $0.end ?? .distantFuture, right = $1.end ?? .distantFuture
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }
        for session in sessions {
            guard !Task.isCancelled else { return ReadingStatistics() }
            guard sessionIDs.insert(session.id).inserted, let end = session.end, end <= now,
                  end >= session.start, session.pausedSeconds >= 0 else { continue }
            let elapsed = end.timeIntervalSince(session.start)
            guard elapsed.isFinite, elapsed < Double(Int.max) else { continue }
            let seconds = max(0, Int(elapsed) - session.pausedSeconds)
            var pages = 0
            var hasPages = false
            if let startPage = session.startPage, let endPage = session.endPage,
               startPage >= 0, endPage >= startPage {
                hasPages = true
                if endPage > startPage {
                    let new = startPage..<endPage
                    let existing = pageRanges[session.cycleKey, default: []]
                    let overlap = existing.reduce(0) { $0 + max(0, min($1.upperBound, new.upperBound) - max($1.lowerBound, new.lowerBound)) }
                    pages = new.count - overlap
                    var merged: [Range<Int>] = []
                    for range in (existing + [new]).sorted(by: { $0.lowerBound < $1.lowerBound }) {
                        if let last = merged.last, range.lowerBound <= last.upperBound {
                            merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
                        } else { merged.append(range) }
                    }
                    pageRanges[session.cycleKey] = merged
                }
            }
            // Deduplicate page coverage over ALL history before selecting a period.
            guard contains(end) else { continue }
            result.events.append(.init(id: session.id, bookID: session.bookID, start: session.start, end: end, seconds: seconds, pages: hasPages ? pages : nil, readID: session.readID))
            result.sessions += 1
            result.seconds += seconds
            result.pages += pages
            if hasPages { result.sessionsWithPages += 1 }
            if let i = index(end) {
                result.activity[i].sessions += 1
                result.activity[i].seconds += seconds
                result.activity[i].pages += pages
            }
        }
        var reviews: [String: StatisticsInput.ReviewValue] = [:]
        for review in input.reviews where (1...5).contains(review.rating) {
            if let previous = reviews[review.bookID], previous.updatedAt > review.updatedAt { continue }
            reviews[review.bookID] = review
        }
        let ratings = reviews.values.filter { contains($0.createdAt) }.map(\.rating)
        result.ratingCount = ratings.count
        result.averageRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
        result.activeDays = ReadingDayCalculator.days(events: result.events, checkIns: input.checkIns, calendar: calendar, now: now, interval: interval)
        return result
    }
}
