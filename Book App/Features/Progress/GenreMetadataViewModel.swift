import Foundation
import Observation

@MainActor @Observable
final class GenreMetadataViewModel {
    private(set) var isLoading = false
    private(set) var message: String?

    func fillMissing(library: LibraryStore, repository: any BookRepository) async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }
        let scope = library.accountScope
        let candidates = library.books.filter { $0.genreChips.isEmpty }
        var updated = 0
        var failures = 0
        for book in candidates {
            guard !Task.isCancelled, scope?.isActive != false else { return }
            do {
                let workID = OpenLibraryGenre.workID(book.sourceBookID ?? book.id)
                let results = try await repository.searchBooks(
                    query: workID.map { "key:\"\($0)\"" } ?? book.title,
                    filter: workID == nil ? .title : .all)
                guard !Task.isCancelled, scope?.isActive != false else { return }
                let matches = results.filter { result in
                    if let workID { return OpenLibraryGenre.workID(result.id) == workID }
                    // Legacy local IDs require an unambiguous exact title and author match.
                    return result.title.caseInsensitiveCompare(book.title) == .orderedSame &&
                        !Set(result.authors.map { $0.lowercased() }).isDisjoint(with: book.authors.map { $0.lowercased() })
                }
                guard matches.count == 1, let result = matches.first, !result.genreChips.isEmpty,
                      let current = library.book(id: book.id),
                      current.sourceBookID == book.sourceBookID,
                      current.genreChips.isEmpty else { continue }
                library.applyMetadata(result, bookID: book.id, fillGenres: true)
                if library.persistenceError == nil { updated += 1 } else { failures += 1 }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, scope?.isActive != false else { return }
                failures += 1
            }
        }
        guard scope?.isActive != false else { return }
        if failures > 0 {
            message = String(localized: "Updated \(updated) books. Some lookups failed. Check your connection and try again.")
        } else {
            message = String(localized: "Updated \(updated) books. Any remaining gaps have no recognised genre or confident catalogue match. You can edit them manually.")
        }
    }
}
