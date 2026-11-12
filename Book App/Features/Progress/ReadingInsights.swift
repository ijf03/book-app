import Foundation

nonisolated struct ReadingInsights: Sendable {
    struct Count: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let count: Int
    }
    struct FinishedBook: Identifiable, Sendable {
        let id: String
        let title: String
        let coverURL: URL?
    }
    struct Day: Identifiable, Sendable {
        var id: Date { date }
        let date: Date
        let number: Int
        let active: Bool
        let best: Bool
        let finished: Bool
    }
    struct Month: Identifiable, Sendable {
        var id: Date { date }
        let date: Date
        var books: [FinishedBook] = []
        var days: [Day] = []
        var leadingDays = 0
        var pages = 0
        var seconds = 0
        var activeDays = 0
        var pagesPerHour: Double?
        var sessionMinutes: Double?
        var radar: [Double] {
            [Double(books.count), Double(pages), Double(seconds) / 3600,
             Double(activeDays), pagesPerHour ?? 0, sessionMinutes ?? 0]
        }
    }
    var months: [Month] = []
    var comparisonMonths: [Month] = []
    var authors: [Count] = []
    var genres: [Count] = []
    var ratings: [Count] = []
    var untaggedBooks = 0
    var longestStreak = 0
    var longestStart: Date?
    var longestEnd: Date?
    var currentStreak = 0
    var pagesPerHour: Double?
    var pagesPerSession: Double?
    var daysToFinish: Double?
    var completionSamples = 0
    var activeDaysPerMonth: Double?
}

/// Derived only; nothing here is persisted or uploaded.
nonisolated enum ReadingInsightsCalculator {
    static func calculate(_ input: StatisticsInput, statistics: ReadingStatistics,
                          calendar: Calendar, now: Date, includeComparison: Bool = true, displayEnd: Date? = nil) -> ReadingInsights {
        var result = ReadingInsights()
        guard let interval = statistics.interval else { return result }
        func contains(_ date: Date) -> Bool {
            date >= interval.start && date < interval.end && date <= now
        }
        var seenBooks = Set<String>()
        let completed = input.completedReads.filter {
            $0.completed && seenBooks.insert($0.cycleKey).inserted && ($0.completedAt.map(contains) ?? false)
        }
        func counts(_ values: [String]) -> [ReadingInsights.Count] {
            Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
                .map { ReadingInsights.Count(name: $0.key, count: $0.value) }
                .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
        }
        result.authors = counts(completed.flatMap { Array(Set($0.authors.filter { !$0.isEmpty })) })
        result.genres = counts(completed.flatMap(\.genreChips))
        result.untaggedBooks = completed.filter { $0.genreChips.isEmpty }.count
        let reviews = Dictionary(input.reviews.filter { (1...5).contains($0.rating) }
            .map { ($0.bookID, $0) }, uniquingKeysWith: { $0.updatedAt > $1.updatedAt ? $0 : $1 })
        result.ratings = (1...5).map { rating in
            .init(name: "\(rating) ★", count: reviews.values.filter { $0.rating == rating && contains($0.createdAt) }.count)
        }
        let timedPages = statistics.events.filter { $0.seconds > 0 && $0.pages != nil }
        let pageEvents = statistics.events.compactMap(\.pages)
        let seconds = timedPages.reduce(0) { $0 + $1.seconds }
        if seconds > 0 { result.pagesPerHour = Double(timedPages.reduce(0) { $0 + ($1.pages ?? 0) }) * 3600 / Double(seconds) }
        if !pageEvents.isEmpty { result.pagesPerSession = Double(pageEvents.reduce(0, +)) / Double(pageEvents.count) }

        // First recorded finished session is an honest proxy, not an invented start date.
        let all = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now)
        let firstSessions = Dictionary(all.events.map { ($0.cycleKey, $0.start) }, uniquingKeysWith: min)
        let durations = completed.compactMap { book -> Int? in
            guard let end = book.completedAt, let start = book.startedAt ?? firstSessions[book.cycleKey], start <= end else { return nil }
            return (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1
        }
        result.completionSamples = durations.count
        if !durations.isEmpty { result.daysToFinish = Double(durations.reduce(0, +)) / Double(durations.count) }

        // Activity means positive recorded reading time; marking completed alone is a separate marker.
        let active = statistics.activeDays
        let ordered = active.sorted()
        var run: [Date] = [], best: [Date] = []
        for day in ordered {
            if let last = run.last, calendar.date(byAdding: .day, value: 1, to: last) != day { run = [] }
            run.append(day)
            if run.count > best.count { best = run }
        }
        result.longestStreak = best.count
        result.longestStart = best.first
        result.longestEnd = best.last
        let bestSet = Set(best)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        if run.last == today || run.last == yesterday { result.currentStreak = run.count }
        let completionDays = Set(completed.compactMap { $0.completedAt.map { calendar.startOfDay(for: $0) } })
        var cursor = calendar.dateInterval(of: .month, for: interval.start)?.start ?? interval.start
        var fullMonthActive: [Int] = []
        while cursor < (displayEnd ?? interval.end), result.months.count < 1200 {
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            var month = ReadingInsights.Month(date: cursor)
            month.leadingDays = (calendar.component(.weekday, from: cursor) + 6) % 7 // Sunday first
            month.books = completed.filter { $0.completedAt.map { $0 >= cursor && $0 < next } ?? false }
                .sorted { ($0.completedAt ?? now) < ($1.completedAt ?? now) }
                .map { .init(id: $0.cycleKey, title: $0.title, coverURL: $0.coverURL) }
            let events = statistics.events.filter { $0.end >= cursor && $0.end < next }
            month.pages = events.reduce(0) { $0 + ($1.pages ?? 0) }
            month.seconds = events.reduce(0) { $0 + $1.seconds }
            month.activeDays = active.filter { $0 >= cursor && $0 < next }.count
            let timed = events.filter { $0.seconds > 0 && $0.pages != nil }
            let timedSeconds = timed.reduce(0) { $0 + $1.seconds }
            if timedSeconds > 0 { month.pagesPerHour = Double(timed.reduce(0) { $0 + ($1.pages ?? 0) }) * 3600 / Double(timedSeconds) }
            if !events.isEmpty { month.sessionMinutes = Double(month.seconds) / Double(events.count) / 60 }
            var day = cursor
            while day < next {
                month.days.append(.init(date: day, number: calendar.component(.day, from: day),
                                        active: active.contains(day), best: bestSet.contains(day),
                                        finished: completionDays.contains(day)))
                guard let following = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = following
            }
            if cursor >= interval.start && next <= interval.end && next <= today { fullMonthActive.append(month.activeDays) }
            result.months.append(month)
            cursor = next
        }
        if !fullMonthActive.isEmpty { result.activeDaysPerMonth = Double(fullMonthActive.reduce(0, +)) / Double(fullMonthActive.count) }
        result.comparisonMonths = result.months
        if includeComparison, result.months.count == 1, let current = result.months.first,
           let previous = calendar.date(byAdding: .month, value: -1, to: current.date),
           let previousEnd = calendar.date(byAdding: .day, value: -1, to: current.date) {
            let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(period: .custom, from: previous, to: previousEnd), calendar: calendar, now: now)
            let prior = calculate(input, statistics: stats, calendar: calendar, now: now, includeComparison: false)
            result.comparisonMonths = prior.months + result.months
        }
        return result
    }
}
