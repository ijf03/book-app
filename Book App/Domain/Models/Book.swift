import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String

    var title: String
    var authors: [String]
    var description: String?
    var coverURL: URL?

    var pageCount: Int?
    var status: ReadingStatus
    var format: ReadingFormat

    // Preserve local identity for existing notes and sessions.
    var sourceBookID: String? = nil
    var completedAt: Date? = nil
    var progress: ReadingProgress = .empty

    var authorText: String {
        authors.joined(separator: ", ")
    }
}
