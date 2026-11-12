import Foundation
import Observation

@MainActor @Observable
final class BookDiscoveryViewModel {
    struct Shelf: Identifiable {
        let id: String
        let title: String
        let books: [BookSearchResult]
    }
    struct Recommendation: Identifiable {
        let book: BookSearchResult
        let reason: String
        var id: String { book.id }
    }

    private(set) var featured: [Recommendation] = []
    private(set) var moreToExplore: [Recommendation] = []

    // Weight repeated authors and genres from actual reading, without inferring interests from a bio.
    static func relevance(of candidate: BookSearchResult, books: [Book], profile: ReadingBehaviour? = nil) -> Double {
        let authors = Set(candidate.authors.map { $0.lowercased() })
        let genres = Set(candidate.genreChips.map { $0.lowercased() })
        let base = books.filter { $0.status == .reading || $0.status == .completed }.reduce(0) { score, book in
            score + Set(book.authors.map { $0.lowercased() }).intersection(authors).count * 3
                + Set(book.genreChips.map { $0.lowercased() }).intersection(genres).count * 2
        }
        return Double(base) + (profile?.match(genres: candidate.genreChips, pages: candidate.pageCount).score ?? 0)
    }

    struct Seed: Equatable {
        let title: String
        let query: String
        let filter: BookSearchFilter
        var id: String { filter.rawValue + ":" + query }
    }
    static let topics = ["All", "Fantasy", "Mystery", "Science fiction", "Romance", "History", "Biography"]
    var topic = "All"
    private(set) var shelves: [Shelf] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private let repository: any BookRepository
    private var generation = UUID()
    private var loadedKey: String?

    init(repository: any BookRepository) { self.repository = repository }

    static func seeds(books: [Book], topic: String) -> [Seed] {
        let read = books.filter { $0.status == .reading || $0.status == .completed }
        func ranked(_ values: [String]) -> [String] {
            let clean = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let grouped = Dictionary(grouping: clean, by: { $0.lowercased() })
            return grouped.values.sorted {
                $0.count == $1.count ? ($0.first ?? "") < ($1.first ?? "") : $0.count > $1.count
            }.compactMap { $0.sorted().first }
        }
        var result: [Seed] = []
        for author in ranked(read.flatMap { Array(Set($0.authors)) }).prefix(1) {
            result.append(.init(title: String(localized: "More by \(author)"), query: author, filter: .author))
        }
        let genres = ranked(read.flatMap(\.genreChips))
        if let genre = genres.first {
            result.append(.init(title: String(localized: "Because you read \(genre)"), query: subjectQuery(genre), filter: .all))
        }
        if topic == "All" {
            if result.isEmpty {
                result.append(.init(title: String(localized: "Explore all genres"), query: "*", filter: .all))
            }
            return result
        }
        let explore = Seed(title: String(localized: "Explore \(topic)"), query: subjectQuery(topic), filter: .all)
        if !result.contains(where: { $0.query.lowercased() == explore.query.lowercased() }) { result.append(explore) }
        return result
    }

    static func subjectQuery(_ topic: String) -> String {
        let escaped = topic.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "subject:\"\(escaped)\""
    }

    func load(books: [Book], scope: AccountStorageScope?, force: Bool = false, sessions: [ReadingSession] = [], reviews: [BookReview] = []) async {
        let profile = ReadingBehaviourCalculator.calculate(StatisticsInput(books: books, sessions: sessions, reviews: reviews))
        var seeds = topic == "All" ? Self.seeds(books: books, topic: topic) : [
            Seed(title: String(localized: "Explore \(topic)"), query: Self.subjectQuery(topic), filter: .all)
        ]
        let preferred = profile.genres.filter { $0.completed >= 2 }.max {
            profile.match(genres: [$0.title], pages: nil).score < profile.match(genres: [$1.title], pages: nil).score
        }
        if topic == "All", let preferred {
            let personal = Seed(title: String(localized: "Based on your reading history: \(preferred.title)"),
                                query: Self.subjectQuery(preferred.title), filter: .all)
            seeds = [personal] + seeds.filter { $0.query != personal.query }
        }
        let owned = Set(books.flatMap { [$0.id, $0.sourceBookID].compactMap { $0 } })
        let key = seeds.map(\.id).joined(separator: "|") + owned.sorted().joined(separator: "|") + String(books.hashValue) + String(reviews.hashValue) + String(sessions.hashValue)
        guard scope?.isActive != false else { shelves = []; featured = []; moreToExplore = []; return }
        guard force || loadedKey != key else { return }
        let token = UUID()
        generation = token
        isLoading = true
        loadedKey = nil
        error = nil
        shelves = []
        featured = []
        moreToExplore = []
        defer { if generation == token { isLoading = false } }
        var seen = owned
        var failed = false
        let selectedSeeds = seeds.count > 2 ? [seeds[0], seeds[seeds.count - 1]] : seeds
        for seed in selectedSeeds {
            do {
                try Task.checkCancellation()
                let results = try await repository.searchBooks(query: seed.query, filter: seed.filter)
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                let available = results.filter { seen.insert($0.id).inserted }
                if !available.isEmpty {
                    shelves.append(.init(id: seed.id, title: seed.title, books: Array(available.prefix(6))))
                }
            } catch {
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                failed = true
                self.error = (error as? OpenLibraryError)?.errorDescription ?? String(localized: "Open Library couldn’t be reached. Please wait a minute before retrying suggestions.")
                break
            }
        }
        let candidates = shelves.flatMap { shelf in
            shelf.books.map { Recommendation(book: $0, reason: shelf.title) }
        }
        // Keep the catalogue order for equally relevant matches.
        let ranked = candidates.enumerated().sorted {
            let lhs = Self.relevance(of: $0.element.book, books: books, profile: profile)
            let rhs = Self.relevance(of: $1.element.book, books: books, profile: profile)
            return lhs == rhs ? $0.offset < $1.offset : lhs > rhs
        }.map(\.element)

        var described: [Recommendation] = []
        var withoutSynopsis: [Recommendation] = []
        // Bound detail requests; missing descriptions must not trigger a request for the entire catalogue.
        for candidate in ranked.prefix(2) {
            do {
                try Task.checkCancellation()
                let detail = try await repository.synopsis(for: candidate.book)
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                let reasons = profile.match(genres: detail.genreChips, pages: detail.pageCount).reasons
                let recommendation = Recommendation(book: detail, reason: reasons.isEmpty ? candidate.reason : reasons.joined(separator: " "))
                if let synopsis = detail.description, !synopsis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    described.append(recommendation)
                } else {
                    withoutSynopsis.append(recommendation)
                }
                featured = Array(described.prefix(2))
                moreToExplore = Array(described.dropFirst(2).prefix(2))
                if described.count == 2 { break }
            } catch {
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                failed = true
                self.error = (error as? OpenLibraryError)?.errorDescription ?? String(localized: "Some book synopses couldn’t load. Please wait a minute before retrying suggestions.")
                break
            }
        }
        if featured.count < 2 {
            featured += withoutSynopsis.prefix(2 - featured.count)
        }
        let featuredIDs = Set(featured.map(\.id))
        moreToExplore = Array(ranked.filter { !featuredIDs.contains($0.id) }.prefix(2))
        if !failed { loadedKey = key }
    }
}
