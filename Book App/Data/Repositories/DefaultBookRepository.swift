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
                pageCount: nil
            )
        }
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
