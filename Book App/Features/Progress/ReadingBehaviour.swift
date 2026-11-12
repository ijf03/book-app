import Foundation

nonisolated struct ReadingBehaviour: Sendable {
    struct Outcome: Identifiable, Sendable {
        let id: String
        let title: String
        var completed = 0
        var abandoned = 0
        var reading = 0
        var days: [Double] = []
        var ratings: [Int] = []
        var resolved: Int { completed + abandoned }
        var completionRate: Double? { resolved > 0 ? Double(completed) / Double(resolved) : nil }
        var averageDays: Double? { days.isEmpty ? nil : days.reduce(0, +) / Double(days.count) }
        var averageRating: Double? { ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count) }
    }
    struct FormatUsage: Identifiable, Sendable {
        let id: String
        let title: String
        var completions = 0
        var sessions = 0
    }
    var genres: [Outcome] = []
    var lengths: [Outcome] = []
    var formats: [FormatUsage] = []
    var completed = 0
    var abandoned = 0
    var averageProgress: Double?
    var progressSamples = 0
    var averageAbandonedProgress: Double?
    var abandonedProgressSamples = 0
    var medianFinishedPages: Double?
    var lengthSamples = 0
    var averageDays: Double?
    var durationSamples = 0
    var averageCompletedRating: Double?
    var ratingSamples = 0
    var missingGenres = 0
    var missingLengths = 0
    var undatedCompletions = 0
    var recentGenre: String?
    var insights: [String] = []
    var summary = String(localized: "Your reading profile is taking shape. Record reading progress, finished books and reviews to discover your patterns.")

    static func lengthID(_ pages: Int) -> String {
        pages < 300 ? "short" : pages < 600 ? "medium" : "long"
    }

    /// Rank only using available catalogue metadata; never request extra metadata to score a book.
    func match(genres candidateGenres: [String], pages: Int?) -> (score: Double, reasons: [String]) {
        var score = 0.0
        var reasons: [String] = []
        for candidate in candidateGenres {
            guard let genre = genres.first(where: { $0.id == candidate.lowercased() }) else { continue }
            score += Double(genre.completed) * 2 - Double(genre.abandoned) * 2
            if let rating = genre.averageRating { score += (rating - 3) * 2 }
            if genre.completed >= 2 {
                reasons.append(String(localized: "You have finished \(genre.completed) \(genre.title) books."))
            }
            if genre.ratings.count >= 2, let rating = genre.averageRating, rating >= 4 {
                reasons.append(String(localized: "You rate completed \(genre.title) books \(rating.formatted(.number.precision(.fractionLength(1))))/5 on average."))
            }
            if recentGenre?.lowercased() == genre.id { score += 2 }
        }
        if let pages, pages > 0, let band = lengths.first(where: { $0.id == Self.lengthID(pages) }),
           band.resolved >= 3, let rate = band.completionRate {
            score += (rate - 0.5) * 6
            if rate >= 0.7 {
                reasons.append(String(localized: "You finished \(band.completed) of \(band.resolved) resolved books in this length range."))
            }
        }
        return (score, Array(reasons.prefix(2)))
    }
}

/// Personal history only. Unknown metadata and dates never become zero-valued evidence.
nonisolated enum ReadingBehaviourCalculator {
    static func calculate(_ input: StatisticsInput, now: Date = Date(), calendar: Calendar = .current) -> ReadingBehaviour {
        var result = ReadingBehaviour()
        let books = Dictionary(input.books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.id < $1.id }
        var seenCycles = Set<String>()
        let completedReads = input.completedReads.filter {
            $0.completed && ($0.completedAt.map { $0 <= now } ?? true) && seenCycles.insert($0.cycleKey).inserted
        }
        let completedIDs = Set(completedReads.map(\.id))
        let reviews = Dictionary(input.reviews.filter {
            (1...5).contains($0.rating) && $0.createdAt <= now && $0.updatedAt <= now
        }.map { ($0.bookID, $0) }, uniquingKeysWith: { $0.updatedAt > $1.updatedAt ? $0 : $1 })
        let all = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now)
        let events = Dictionary(grouping: all.events, by: \.cycleKey)
        var durations: [String: [Double]] = [:]
        for read in completedReads {
            guard let end = read.completedAt else { result.undatedCompletions += 1; continue }
            let firstSession = events[read.cycleKey, default: []].filter { $0.end <= end }.map(\.start).min()
            guard let start = read.startedAt ?? firstSession, start <= end, start <= now else { continue }
            let days = Double((calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1)
            durations[read.id, default: []].append(days)
        }
        let allDays = durations.values.flatMap { $0 }
        result.durationSamples = allDays.count
        result.averageDays = mean(allDays)
        var genreMap: [String: ReadingBehaviour.Outcome] = [:]
        var lengthMap: [String: ReadingBehaviour.Outcome] = [
            "short": .init(id: "short", title: String(localized: "Under 300 pages")),
            "medium": .init(id: "medium", title: String(localized: "300–599 pages")),
            "long": .init(id: "long", title: String(localized: "600+ pages"))
        ]
        var completedLengths: [Double] = []
        var completedRatings: [Double] = []
        var currentProgress: [Double] = []
        var stoppedProgress: [Double] = []
        // Outcome comparisons count each title once; rereads supply timing samples only.
        for book in books {
            let finished = completedIDs.contains(book.id)
            let abandoned = book.status == "abandoned" && !finished
            let reading = book.status == "reading"
            guard finished || abandoned || reading else { continue }
            if finished { result.completed += 1 }
            if abandoned { result.abandoned += 1 }
            if book.genreChips.isEmpty { result.missingGenres += 1 }
            if book.pageCount == nil || (book.pageCount ?? 0) <= 0 { result.missingLengths += 1 }
            if reading, let progress = validProgress(book.progressPercentage) { currentProgress.append(progress) }
            if abandoned, let progress = validProgress(book.progressPercentage) { stoppedProgress.append(progress) }
            let rating = finished ? reviews[book.id]?.rating : nil
            if let rating { completedRatings.append(Double(rating)) }
            func accumulate(_ outcome: inout ReadingBehaviour.Outcome) {
                if finished { outcome.completed += 1 }
                if abandoned { outcome.abandoned += 1 }
                if reading { outcome.reading += 1 }
                outcome.days += durations[book.id, default: []]
                if let rating { outcome.ratings.append(rating) }
            }
            for genre in book.genreChips {
                let key = genre.lowercased()
                var outcome = genreMap[key] ?? .init(id: key, title: genre)
                accumulate(&outcome)
                genreMap[key] = outcome
            }
            if let pages = book.pageCount, pages > 0 {
                let key = ReadingBehaviour.lengthID(pages)
                if var outcome = lengthMap[key] { accumulate(&outcome); lengthMap[key] = outcome }
                if finished { completedLengths.append(Double(pages)) }
            }
        }
        result.genres = genreMap.values.sorted {
            $0.completed == $1.completed ? $0.title < $1.title : $0.completed > $1.completed
        }
        result.lengths = ["short", "medium", "long"].compactMap { lengthMap[$0] }
        result.averageProgress = mean(currentProgress)
        result.progressSamples = currentProgress.count
        result.averageAbandonedProgress = mean(stoppedProgress)
        result.abandonedProgressSamples = stoppedProgress.count
        result.lengthSamples = completedLengths.count
        let lengths = completedLengths.sorted()
        if !lengths.isEmpty {
            let middle = lengths.count / 2
            result.medianFinishedPages = lengths.count.isMultiple(of: 2) ? (lengths[middle - 1] + lengths[middle]) / 2 : lengths[middle]
        }
        result.averageCompletedRating = mean(completedRatings)
        result.ratingSamples = completedRatings.count
        let names = ["physical": String(localized: "Physical"), "ebook": String(localized: "Ebook"),
                     "audiobook": String(localized: "Audiobook"), "immersive": String(localized: "Immersive reading")]
        let validSessions = Set(all.events.map(\.id))
        var seenSessions = Set<UUID>()
        let sessions = input.sessions.filter { validSessions.contains($0.id) && seenSessions.insert($0.id).inserted }
        result.formats = ["physical", "ebook", "audiobook", "immersive"].map { format in
            .init(id: format, title: names[format] ?? format,
                  completions: completedReads.filter { $0.format == format }.count,
                  sessions: sessions.filter { ($0.formats ?? []).contains(format) }.count)
        }

        if let genre = result.genres.first, genre.completed >= 2 {
            result.insights.append(String(localized: "Your most-finished tagged genre is \(genre.title), with \(genre.completed) completed books."))
        }
        if let median = result.medianFinishedPages, result.lengthSamples >= 3 {
            result.insights.append(String(localized: "The typical book you finish is \(Int(median)) pages long (median of \(result.lengthSamples) books)."))
        }
        let orderedFormats = result.formats.sorted { $0.completions == $1.completions ? $0.id < $1.id : $0.completions > $1.completions }
        if let format = orderedFormats.first, format.completions >= 3,
           format.completions > (orderedFormats.dropFirst().first?.completions ?? 0) {
            result.insights.append(String(localized: "You most often finish in \(format.title) format: \(format.completions) completed reads."))
        }
        for genre in result.genres where genre.days.count >= 2 {
            // Compare with distinct reads outside this genre, not overlapping multi-genre totals.
            let genreBookIDs = Set(books.filter { $0.genreChips.contains { $0.lowercased() == genre.id } }.map(\.id))
            let other = durations.filter { !genreBookIDs.contains($0.key) }.values.flatMap { $0 }
            if other.count >= 2, let average = genre.averageDays, let otherAverage = mean(other), average < otherAverage * 0.8 {
                result.insights.append(String(localized: "In your dated records, \(genre.title) takes \(average.formatted(.number.precision(.fractionLength(1)))) days on average versus \(otherAverage.formatted(.number.precision(.fractionLength(1)))) for other genres (\(genre.days.count) versus \(other.count) reads)."))
                break
            }
        }
        for band in result.lengths where band.resolved >= 3 && band.abandoned >= 2 {
            result.insights.append(String(localized: "For books of \(band.title.lowercased()), you finished \(band.completed) and marked \(band.abandoned) as did not finish. Length may be worth considering for your next read."))
        }

        if let recentStart = calendar.date(byAdding: .day, value: -30, to: now),
           let previousStart = calendar.date(byAdding: .day, value: -60, to: now) {
            func activeBooks(from start: Date, to end: Date) -> Set<String> {
                Set(all.events.filter { $0.end >= start && $0.end < end && $0.seconds > 0 }.map(\.bookID))
                    .union(completedReads.filter { $0.completedAt.map { $0 >= start && $0 < end } ?? false }.map(\.id))
            }
            let recent = activeBooks(from: recentStart, to: now.addingTimeInterval(0.001))
            let previous = activeBooks(from: previousStart, to: recentStart)
            let tagged = books.filter { !$0.genreChips.isEmpty }
            let recentTagged = tagged.filter { recent.contains($0.id) }
            let previousTagged = tagged.filter { previous.contains($0.id) }
            if recentTagged.count >= 3 && previousTagged.count >= 3 {
                for genre in result.genres {
                    let current = recentTagged.filter { $0.genreChips.contains { $0.lowercased() == genre.id } }.count
                    let prior = previousTagged.filter { $0.genreChips.contains { $0.lowercased() == genre.id } }.count
                    if current >= 2 && Double(current) / Double(recentTagged.count) - Double(prior) / Double(previousTagged.count) >= 0.2 {
                        result.recentGenre = genre.title
                        result.insights.append(String(localized: "You have been reading more \(genre.title): \(current) of \(recentTagged.count) tagged books in the last 30 days, versus \(prior) of \(previousTagged.count) in the preceding 30 days."))
                        break
                    }
                }
            }
        }
        if !result.insights.isEmpty {
            result.summary = result.insights.prefix(2).joined(separator: " ")
        } else if result.completed + result.abandoned > 0 {
            result.summary = String(localized: "Your history includes \(result.completed) completed books and \(result.abandoned) marked did not finish. Keep recording genres, dates and progress to reveal stronger patterns.")
        }
        return result
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    private static func validProgress(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }
}
