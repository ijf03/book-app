import Foundation

enum OpenLibraryError: LocalizedError {
    case cooldown
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .cooldown:
            return "Book requests are paused briefly. Please wait a few minutes before trying again."
        case .invalidURL:
            return "The book search URL could not be created."

        case .invalidResponse:
            return "Open Library returned an invalid response."

        case .httpError(let statusCode):
            return "Open Library returned HTTP \(statusCode)."
        }
    }
}

struct OpenLibraryRemoteDataSource: Sendable {

    func search(
        query: String,
        filter: BookSearchFilter
    ) async throws -> [OpenLibraryBookDTO] {

        guard var components = URLComponents(
            string: "https://openlibrary.org/search.json"
        ) else {
            throw OpenLibraryError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(
                name: "limit",
                value: "20"
            ),
            URLQueryItem(
                name: "fields",
                value: "key,title,author_name,cover_i,first_publish_year,edition_key,number_of_pages_median,subject"
            )
        ]

        switch filter {
        case .all:
            queryItems.append(
                URLQueryItem(
                    name: "q",
                    value: query
                )
            )

        case .title:
            queryItems.append(
                URLQueryItem(
                    name: "title",
                    value: query
                )
            )

        case .author:
            queryItems.append(
                URLQueryItem(
                    name: "author",
                    value: query
                )
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        let data = try await OpenLibraryRequestClient.shared.data(for: url)
        return try JSONDecoder().decode(OpenLibrarySearchResponseDTO.self, from: data).docs
    }
}
