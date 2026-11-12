import Foundation

nonisolated enum GenreTags {
    static func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 100 && seen.insert($0.lowercased()).inserted }
            .prefix(30).map { $0 }
    }
}

/// Catalogue facts only. The reader's format, dates, ratings and progress remain separate.
nonisolated struct BookMetadata: Codable, Hashable, Sendable {
    var schemaVersion = 1
    var workID: String
    var firstPublished: String?
    var edition: BookEdition?
    var communityRating: Double?
    var communityRatingCount: Int?
    var fetchedAt: Date

    var sourceURL: URL? { URL(string: "https://openlibrary.org" + workID) }
    var isValid: Bool {
        schemaVersion == 1 && OpenLibraryGenre.workID(workID) != nil
        && (firstPublished?.count ?? 0) <= 200
        && (edition?.isValid ?? true)
        && (communityRating.map { $0.isFinite && (0...5).contains($0) } ?? true)
        && (communityRatingCount.map { $0 >= 0 } ?? true)
        && fetchedAt.timeIntervalSinceReferenceDate.isFinite
    }
}

nonisolated struct BookEdition: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var publishers: [String] = []
    var published: String?
    var languages: [String] = []
    var isbn: [String] = []
    var pages: Int?
    var physicalFormat: String?
    var coverURL: URL?
    var sourceURL: URL? { URL(string: "https://openlibrary.org" + id) }
    var isValid: Bool {
        id.range(of: "^/books/OL[0-9]+M$", options: .regularExpression) != nil
        && title.count <= 10000 && publishers.count <= 30 && languages.count <= 30 && isbn.count <= 30
        && (published?.count ?? 0) <= 200 && (physicalFormat?.count ?? 0) <= 200
        && (pages.map { $0 >= 0 } ?? true)
    }
}

extension BookSearchResult {
    init(book: Book) {
        id = book.sourceBookID ?? book.id
        title = book.title
        authors = book.authors
        description = book.description
        coverURL = book.coverURL
        pageCount = book.pageCount
        genre = book.genre
        genres = book.genres
        metadata = book.metadata
    }

    func selecting(_ edition: BookEdition) -> Self {
        var result = self
        result.metadata?.edition = edition
        result = .init(id: id, title: title, authors: authors, description: description,
                       coverURL: edition.coverURL ?? coverURL, pageCount: edition.pages,
                       genre: genre, genres: genres, metadata: result.metadata)
        return result
    }
}
