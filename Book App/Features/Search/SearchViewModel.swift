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
    var selectedGenre = "All"

    private(set) var state: State = .idle

    private let repository: any BookRepository
    private var requestID = UUID()

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func clear() {
        requestID = UUID()
        state = .idle
    }

    func search() async {
        let token = UUID()
        requestID = token

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
                    query: selectedGenre == "All" ? query : "(\(query)) AND \(BookDiscoveryViewModel.subjectQuery(selectedGenre))",
                    filter: selectedFilter
                )

            try Task.checkCancellation()

            guard requestID == token else { return }
            state = .loaded(results)

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled, requestID == token else { return }
            print("BOOK SEARCH ERROR:")
            print(error)
            print(String(describing: error))

            state = .failed(
                (error as? OpenLibraryError)?.errorDescription ?? "We couldn't search for books. Please wait a minute before trying again."
            )
        }
    }
}
