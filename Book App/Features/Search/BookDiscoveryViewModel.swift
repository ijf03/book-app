import Foundation
import Observation

@MainActor @Observable
final class BookDiscoveryViewModel {
    struct Shelf: Identifiable {
        let id: String
        let title: String
        let books: [BookSearchResult]
    }
    struct Seed: Equatable {
        let title: String
        let query: String
        let filter: BookSearchFilter
        var id: String { filter.rawValue + ":" + query }
    }
    static let topics = ["Fantasy", "Mystery", "Science fiction", "Romance", "History", "Biography"]
    var topic = "Fantasy"
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
        let genres = ranked(read.compactMap(\.genre))
        if let genre = genres.first {
            result.append(.init(title: String(localized: "Because you read \(genre)"), query: subjectQuery(genre), filter: .all))
        }
        let explore = Seed(title: String(localized: "Explore \(topic)"), query: subjectQuery(topic), filter: .all)
        if !result.contains(where: { $0.query.lowercased() == explore.query.lowercased() }) { result.append(explore) }
        return result
    }

    static func subjectQuery(_ topic: String) -> String {
        let escaped = topic.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "subject:\"\(escaped)\""
    }

    func load(books: [Book], scope: AccountStorageScope?, force: Bool = false) async {
        let seeds = Self.seeds(books: books, topic: topic)
        let owned = Set(books.flatMap { [$0.id, $0.sourceBookID].compactMap { $0 } })
        let key = seeds.map(\.id).joined(separator: "|") + owned.sorted().joined(separator: "|")
        guard scope?.isActive != false else { shelves = []; return }
        guard force || loadedKey != key else { return }
        let token = UUID()
        generation = token
        isLoading = true
        loadedKey = nil
        error = nil
        shelves = []
        defer { if generation == token { isLoading = false } }
        var seen = owned
        var failed = false
        for seed in seeds {
            do {
                try Task.checkCancellation()
                let results = try await repository.searchBooks(query: seed.query, filter: seed.filter)
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                let available = results.filter { seen.insert($0.id).inserted }
                if !available.isEmpty {
                    shelves.append(.init(id: seed.id, title: seed.title, books: Array(available.shuffled().prefix(12))))
                }
            } catch {
                guard !Task.isCancelled, generation == token, scope?.isActive != false else { return }
                failed = true
                self.error = String(localized: "Some suggestions couldn’t load. Check your connection and retry.")
            }
        }
        if !failed { loadedKey = key }
    }
}
