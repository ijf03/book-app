//
//  SearchViewModel.swift
//  Book App
//
//  Created by Sabi on 8/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {

    enum State {
        case idle
        case loading
        case loaded([BookSearchResult])
        case failed(String)
    }

    var searchText = ""
    var selectedFilter: BookSearchFilter = .all

    private(set) var state: State = .idle

    private let repository: any BookRepository

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func search() async {

        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            state = .idle
            return
        }

        state = .loading

        do {
            let results =
                try await repository.searchBooks(
                    query: query,
                    filter: selectedFilter
                )

            try Task.checkCancellation()

            state = .loaded(results)

        } catch is CancellationError {
            return

        } catch {
            print("BOOK SEARCH ERROR:")
            print(error)
            print(String(describing: error))

            state = .failed(
                "We couldn't search for books. Please try again."
            )
        }
    }
}
