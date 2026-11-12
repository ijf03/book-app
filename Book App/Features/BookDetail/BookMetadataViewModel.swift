import Foundation
import Observation

@MainActor @Observable
final class BookMetadataViewModel {
    private(set) var result: BookSearchResult
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var editions: [BookEdition] = []
    private(set) var isLoadingEditions = false
    private(set) var editionError: String?
    private(set) var hasMoreEditions = true
    private var offset = 0

    init(book: BookSearchResult) { result = book }

    func load(using repository: any BookRepository, scope: AccountStorageScope?, synopsisOnly: Bool = false) async {
        guard !isLoading, scope?.isActive != false else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let originalEdition = result.metadata?.edition
            var updated = try await synopsisOnly ? repository.synopsis(for: result) : repository.details(for: result)
            guard !Task.isCancelled, scope?.isActive != false else { return }
            if let selected = result.metadata?.edition, selected != originalEdition {
                updated = updated.selecting(selected)
            }
            result = updated
        } catch {
            guard !Task.isCancelled, scope?.isActive != false else { return }
            self.error = String(localized: "Book information couldn’t load. Your saved book is still available. Please retry.")
        }
    }

    func loadEditions(using repository: any BookRepository, scope: AccountStorageScope?) async {
        guard !isLoadingEditions, hasMoreEditions, scope?.isActive != false else { return }
        isLoadingEditions = true
        editionError = nil
        defer { isLoadingEditions = false }
        do {
            let values = try await repository.editions(workID: result.id, offset: offset)
            guard !Task.isCancelled, scope?.isActive != false else { return }
            var seen = Set(editions.map(\.id))
            editions += values.filter { seen.insert($0.id).inserted }
            offset += 20
            hasMoreEditions = values.count == 20
        } catch {
            guard !Task.isCancelled, scope?.isActive != false else { return }
            editionError = String(localized: "Editions couldn’t load. Please retry.")
        }
    }

    func select(_ edition: BookEdition) { result = result.selecting(edition) }
}
