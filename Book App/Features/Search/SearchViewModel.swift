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

    func apply(_ request: AppRouter.SearchRequest) {
        searchText = request.author ?? ""
        selectedFilter = request.author == nil ? .all : .author
        selectedGenre = request.genre ?? "All"
        clear()
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

        guard !query.isEmpty || selectedGenre != "All" else {
            state = .idle
            return
        }

        state = .loading

        do {
            let subject = BookDiscoveryViewModel.subjectQuery(selectedGenre)
            let requestQuery: String
            let requestFilter: BookSearchFilter
            if selectedGenre == "All" {
                requestQuery = query
                requestFilter = selectedFilter
            } else {
                let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let textQuery = selectedFilter == .all ? query : "\(selectedFilter.rawValue):\"\(escaped)\""
                requestQuery = query.isEmpty ? subject : "(\(textQuery)) AND \(subject)"
                requestFilter = .all
            }
            let results = try await repository.searchBooks(query: requestQuery, filter: requestFilter)

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
