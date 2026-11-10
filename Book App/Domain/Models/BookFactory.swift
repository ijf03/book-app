//
//  BookFactory.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

enum BookFactory {

    static func makeBook(
        from result: BookSearchResult,
        status: ReadingStatus,
        format: ReadingFormat
    ) -> Book {

        Book(
            id: result.id,
            title: result.title,
            authors: result.authors,
            description:
                result.description,
            coverURL:
                result.coverURL,
            pageCount:
                result.pageCount,
            status:
                status,
            format:
                format,
            genre: result.genre,
            progress: .empty
        )
    }
}
