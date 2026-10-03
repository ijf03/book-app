//
//  OpenLibraryRemoteDataSource.swift
//  Book App
//
//  Created by Sabi on 8/10/2026.
//

import Foundation

enum OpenLibraryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
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
                value: "key,title,author_name,cover_i,first_publish_year,edition_key"
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

        var request = URLRequest(url: url)

        request.setValue(
            "BookApp/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenLibraryError.invalidResponse
        }

        print("Open Library status:", httpResponse.statusCode)
        print("Open Library URL:", url.absoluteString)

        guard 200..<300 ~= httpResponse.statusCode else {
            if let body = String(
                data: data,
                encoding: .utf8
            ) {
                print("Open Library response:")
                print(body)
            }

            throw OpenLibraryError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        do {
            let decoded = try JSONDecoder().decode(
                OpenLibrarySearchResponseDTO.self,
                from: data
            )

            return decoded.docs

        } catch {
            print("Open Library decoding error:")
            print(error)

            if let body = String(
                data: data,
                encoding: .utf8
            ) {
                print("Response body:")
                print(body)
            }

            throw error
        }
    }
}
