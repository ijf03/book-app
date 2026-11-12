import Foundation

nonisolated struct CatalogueText: Decodable, Sendable {
    let value: String
    init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) { value = text }
        else { value = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .value) }
    }
    private enum CodingKeys: String, CodingKey { case value }
}

nonisolated struct OpenLibraryWorkDTO: Decodable, Sendable {
    var description: CatalogueText?
    var subjects: [String]?
    var first_publish_date: String?
}

nonisolated struct OpenLibraryEditionsDTO: Decodable, Sendable {
    var entries: [OpenLibraryEditionDTO]
}

nonisolated struct OpenLibraryEditionDTO: Decodable, Sendable {
    struct Reference: Decodable, Sendable { var key: String }
    var key: String
    var title: String
    var publishers: [String]?
    var publish_date: String?
    var languages: [Reference]?
    var isbn_10: [String]?
    var isbn_13: [String]?
    var number_of_pages: Int?
    var physical_format: String?
    var covers: [Int]?
    var description: CatalogueText?

    var edition: BookEdition {
        .init(id: key, title: title, publishers: Array((publishers ?? []).prefix(30)),
              published: publish_date, languages: Array((languages ?? []).prefix(30)).map {
                  let code = String($0.key.split(separator: "/").last ?? "")
                  return Locale.current.localizedString(forLanguageCode: code) ?? code
              }, isbn: Array(((isbn_13 ?? []) + (isbn_10 ?? [])).prefix(30)), pages: number_of_pages.flatMap { $0 > 0 ? $0 : nil },
              physicalFormat: physical_format, coverURL: covers?.first(where: { $0 > 0 }).flatMap {
                  URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg?default=false")
              })
    }
}

nonisolated struct OpenLibraryRatingsDTO: Decodable, Sendable {
    struct Summary: Decodable, Sendable { var average: Double?; var count: Int? }
    var summary: Summary
}

extension OpenLibraryRemoteDataSource {
    func fetch<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: "https://openlibrary.org" + path) else { throw OpenLibraryError.invalidURL }
        let data = try await OpenLibraryRequestClient.shared.data(for: url)
        try Task.checkCancellation()
        return try JSONDecoder().decode(type, from: data)
    }
}
