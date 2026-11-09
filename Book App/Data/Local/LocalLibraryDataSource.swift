//
//  LocalLibraryDataSource.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

enum LocalLibraryError: LocalizedError {
    case unableToCreateDirectory
    case unableToEncode
    case unableToSave
    case unableToDecode

    var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory:
            return "The local library folder could not be created."

        case .unableToEncode:
            return "The library data could not be prepared for saving."

        case .unableToSave:
            return "The library could not be saved."

        case .unableToDecode:
            return "The saved library could not be read."
        }
    }
}

final class LocalLibraryDataSource {
    let scope: AccountStorageScope?


    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        scope: AccountStorageScope? = nil
    ) {
        self.scope = scope
        self.fileManager = fileManager

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        self.decoder = JSONDecoder()
    }

    // MARK: - Load

    func loadBooks() throws -> [Book]? {

        let fileURL = try libraryFileURL()

        print(
            "📂 Looking for library at:",
            fileURL.path
        )

        guard fileManager.fileExists(
            atPath: fileURL.path
        ) else {
            print("📂 No saved library exists yet.")
            return nil
        }

        do {
            let data = try Data(
                contentsOf: fileURL
            )

            let books = try decoder.decode(
                [Book].self,
                from: data
            )

            print(
                "✅ Loaded \(books.count) books from disk."
            )

            return books

        } catch let error as DecodingError {

            print(
                "❌ Library decoding error:",
                error
            )

            throw LocalLibraryError.unableToDecode

        } catch {

            print(
                "❌ Library load error:",
                error
            )

            throw error
        }
    }

    // MARK: - Save

    func saveBooks(
        _ books: [Book]
    ) throws {

        let fileURL = try libraryFileURL()

        do {
            let data = try encoder.encode(
                books
            )

            try data.write(
                to: fileURL,
                options: .atomic
            )

            print(
                "💾 Saved \(books.count) books to:"
            )

            print(fileURL.path)

            guard fileManager.fileExists(
                atPath: fileURL.path
            ) else {
                throw LocalLibraryError.unableToSave
            }

        } catch let error as EncodingError {

            print(
                "❌ Library encoding error:",
                error
            )

            throw LocalLibraryError.unableToEncode

        } catch let error as LocalLibraryError {
            throw error

        } catch {

            print(
                "❌ Library save error:",
                error
            )

            throw LocalLibraryError.unableToSave
        }
    }

    // MARK: - Delete

    func deleteSavedLibrary() throws {

        let fileURL = try libraryFileURL()

        guard fileManager.fileExists(
            atPath: fileURL.path
        ) else {
            return
        }

        try fileManager.removeItem(
            at: fileURL
        )

        print("🗑️ Deleted saved library.")
    }

    // MARK: - File Location

    private func libraryFileURL() throws -> URL {
        if let scope {
            try scope.checkAccess()
            try fileManager.createDirectory(at: scope.directory, withIntermediateDirectories: true)
            return scope.directory.appendingPathComponent("library.json")
        }


        guard let applicationSupportURL =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            throw LocalLibraryError
                .unableToCreateDirectory
        }

        let appFolder =
            applicationSupportURL
                .appendingPathComponent(
                    "BookApp",
                    isDirectory: true
                )

        if !fileManager.fileExists(
            atPath: appFolder.path
        ) {
            do {
                try fileManager.createDirectory(
                    at: appFolder,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                print(
                    "📁 Created BookApp storage folder."
                )

            } catch {

                print(
                    "❌ Could not create storage folder:",
                    error
                )

                throw LocalLibraryError
                    .unableToCreateDirectory
            }
        }

        return appFolder
            .appendingPathComponent(
                "library.json",
                isDirectory: false
            )
    }
}
