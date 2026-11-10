import Foundation

nonisolated struct ExtendedReadingStatistics: Sendable {
    struct BookSummary: Identifiable, Sendable {
        let id: String
        let title: String
        let pages: Int?
        let seconds: Int
        let sessions: Int
        let pace: Double?
        let daysToFinish: Int?
        let finishSeconds: Int?
        let rating: Int?
    }
    struct RatingGroup: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let ratings: [ReadingInsights.Count]
    }
    var books: [BookSummary] = []
    var types: [ReadingInsights.Count] = []
    var languages: [ReadingInsights.Count] = []
    var moods: [ReadingInsights.Count] = []
    var ratingsByType: [RatingGroup] = []
    var ratingsByFormat: [RatingGroup] = []
    var averageFinishSeconds: Double?
    var finishSamples = 0
    var topBooks: [BookSummary] = []
}

/// All calculations share the established session validation, pause subtraction and
/// historical page-coverage deduplication. No current-page snapshots become reading.
nonisolated enum ExtendedStatisticsCalculator {
    static func calculate(_ input: StatisticsInput, statistics: ReadingStatistics,
                          calendar: Calendar, now: Date) -> ExtendedReadingStatistics {
        var result = ExtendedReadingStatistics()
        guard let interval = statistics.interval else { return result }
        func contains(_ date: Date) -> Bool { date >= interval.start && date < interval.end && date <= now }
        func tag(_ value: String?) -> String {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? String(localized: "Not recorded") : trimmed.localizedCapitalized
        }
        func type(_ value: String?) -> String {
            switch value {
            case "fiction": String(localized: "Fiction")
            case "nonfiction": String(localized: "Non-fiction")
            default: String(localized: "Not recorded")
            }
        }
        func format(_ value: String) -> String {
            switch value {
            case "physical": String(localized: "Print")
            case "ebook": String(localized: "Digital")
            case "audiobook": String(localized: "Audio")
            case "immersive": String(localized: "Immersive reading")
            default: String(localized: "Not recorded")
            }
        }
        func counts(_ values: [String]) -> [ReadingInsights.Count] {
            Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
                .map { .init(name: $0.key, count: $0.value) }
                .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
        }
        let books = Dictionary(input.books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let completed = input.completedReads.filter { $0.completed && ($0.completedAt.map(contains) ?? false) }
        let completedIDs = Set(completed.map(\.id))
        let allReviews = Dictionary(input.reviews.filter { (1...5).contains($0.rating) }
            .map { ($0.bookID, $0) }, uniquingKeysWith: { $0.updatedAt > $1.updatedAt ? $0 : $1 })
        let reviews = allReviews.values.filter { contains($0.createdAt) }
        result.types = counts(completed.map { type($0.bookType) })
        result.languages = counts(completed.map { tag($0.language) })
        // Completion date selects the book; its current review supplies the feeling.
        result.moods = counts(completed.map { tag(allReviews[$0.id]?.mood) })
        func groups(_ key: (StatisticsInput.BookValue?) -> String) -> [ExtendedReadingStatistics.RatingGroup] {
            let grouped = Dictionary(grouping: reviews) { key(books[$0.bookID]) }
            return grouped.keys.sorted().map { name in
                .init(name: name, ratings: (1...5).map { rating in
                    .init(name: "\(rating) ★", count: grouped[name, default: []].filter { $0.rating == rating }.count)
                })
            }
        }
        result.ratingsByType = groups { type($0?.bookType) }
        result.ratingsByFormat = groups { format($0?.format ?? "") }
        let all = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now)
        let historical = Dictionary(grouping: all.events, by: \.bookID)
        let selected = Dictionary(grouping: statistics.events, by: \.bookID)
        var finishTimes: [Int] = []
        for book in books.values.sorted(by: { $0.title == $1.title ? $0.id < $1.id : $0.title < $1.title }) {
            let events = selected[book.id, default: []]
            let pages = events.compactMap(\.pages)
            let timed = events.filter { $0.pages != nil && $0.seconds > 0 }
            let timedSeconds = timed.reduce(0) { $0 + $1.seconds }
            let pace = timedSeconds > 0 ? Double(timed.reduce(0) { $0 + ($1.pages ?? 0) }) * 3600 / Double(timedSeconds) : nil
            var days: Int?
            var finishSeconds: Int?
            // Aggregate finish-time samples per cycle; the comparison row shows the latest completed cycle.
            for read in completed.filter({ $0.id == book.id }).sorted(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }) {
                guard let end = read.completedAt else { continue }
                let beforeCompletion = historical[book.id, default: []].filter { $0.end <= end && $0.cycleKey == read.cycleKey }
                if let first = read.startedAt ?? beforeCompletion.map(\.start).min(), first <= end {
                    days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: end)).day ?? 0) + 1
                }
                let seconds = beforeCompletion.reduce(0) { $0 + $1.seconds }
                finishSeconds = seconds > 0 ? seconds : nil
                if seconds > 0 { finishTimes.append(seconds) }
            }
            result.books.append(.init(id: book.id, title: book.title,
                                      pages: pages.isEmpty ? nil : pages.reduce(0, +),
                                      seconds: events.reduce(0) { $0 + $1.seconds }, sessions: events.count,
                                      pace: pace, daysToFinish: days, finishSeconds: finishSeconds,
                                      rating: reviews.first { $0.bookID == book.id }?.rating))
        }
        result.finishSamples = finishTimes.count
        if !finishTimes.isEmpty { result.averageFinishSeconds = Double(finishTimes.reduce(0, +)) / Double(finishTimes.count) }
        // Top means highest current rating among dated completions in the period.
        result.topBooks = result.books.filter { completedIDs.contains($0.id) && allReviews[$0.id] != nil }
            .map { book in
                .init(id: book.id, title: book.title, pages: book.pages, seconds: book.seconds,
                      sessions: book.sessions, pace: book.pace, daysToFinish: book.daysToFinish,
                      finishSeconds: book.finishSeconds, rating: allReviews[book.id]?.rating)
            }
            .sorted { $0.rating == $1.rating ? ($0.title == $1.title ? $0.id < $1.id : $0.title < $1.title) : ($0.rating ?? 0) > ($1.rating ?? 0) }
        result.topBooks = Array(result.topBooks.prefix(3))
        return result
    }
}
