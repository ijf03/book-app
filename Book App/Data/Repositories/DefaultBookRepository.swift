//
//  DefaultBookRepository.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

struct DefaultBookRepository: BookRepository, Sendable {

    private let remoteDataSource: OpenLibraryRemoteDataSource

    init(
        remoteDataSource: OpenLibraryRemoteDataSource
    ) {
        self.remoteDataSource = remoteDataSource
    }

    func searchBooks(
        query: String,
        filter: BookSearchFilter
    ) async throws -> [BookSearchResult] {

        let items = try await remoteDataSource.search(
            query: query,
            filter: filter
        )

        return items.map { item in
            BookSearchResult(
                id: item.key,
                title: item.title,
                authors: item.authorName ?? [],
                description: nil,
                coverURL: coverURL(
                    coverID: item.coverID
                ),
                pageCount: item.numberOfPagesMedian,
                genre: OpenLibraryGenre.primary(from: item.subjects ?? []),
                genres: OpenLibraryGenre.all(from: item.subjects ?? []),
                metadata: OpenLibraryGenre.workID(item.key).map {
                    BookMetadata(workID: $0, firstPublished: item.firstPublishYear.map(String.init), fetchedAt: Date())
                }
            )
        }
    }

    func synopsis(for book: BookSearchResult) async throws -> BookSearchResult {
        try await loadDetails(for: book, includeRatings: false)
    }

    func details(for book: BookSearchResult) async throws -> BookSearchResult {
        try await loadDetails(for: book, includeRatings: true)
    }

    private func loadDetails(for book: BookSearchResult, includeRatings: Bool) async throws -> BookSearchResult {
        guard let workID = OpenLibraryGenre.workID(book.id) else { throw OpenLibraryError.invalidURL }
        let work = try await remoteDataSource.fetch(workID + ".json", as: OpenLibraryWorkDTO.self)
        // Optional endpoints may be incomplete. A missing rating must never hide a synopsis.
        var ratings: OpenLibraryRatingsDTO?
        if includeRatings {
            ratings = try? await remoteDataSource.fetch(workID + "/ratings.json", as: OpenLibraryRatingsDTO.self)
        }
        try Task.checkCancellation()
        let genres = OpenLibraryGenre.all(from: work.subjects ?? [])
        var metadata = book.metadata ?? BookMetadata(workID: workID, fetchedAt: Date())
        metadata.firstPublished = work.first_publish_date ?? metadata.firstPublished
        metadata.communityRating = ratings?.summary.average ?? metadata.communityRating
        metadata.communityRatingCount = ratings?.summary.count ?? metadata.communityRatingCount
        metadata.fetchedAt = Date()
        return .init(id: book.id, title: book.title, authors: book.authors,
                     description: work.description?.value ?? book.description, coverURL: book.coverURL,
                     pageCount: book.pageCount, genre: genres.first ?? book.genre,
                     genres: genres.isEmpty ? book.genreChips : genres, metadata: metadata)
    }

    func editions(workID: String, offset: Int) async throws -> [BookEdition] {
        guard let key = OpenLibraryGenre.workID(workID) else { throw OpenLibraryError.invalidURL }
        let response = try await remoteDataSource.fetch(key + "/editions.json?limit=20&offset=\(offset)", as: OpenLibraryEditionsDTO.self)
        return response.entries.map(\.edition).filter(\.isValid)
    }

    private func coverURL(
        coverID: Int?
    ) -> URL? {

        guard let coverID else {
            return nil
        }

        return URL(
            string:
                "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        )
    }
}
