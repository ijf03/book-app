//
//  LocalBookContentDataSource.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation

enum LocalBookContentError:
    LocalizedError
{
    case unableToCreateDirectory
    case unableToEncode
    case unableToDecode
    case unableToSave

    var errorDescription: String? {

        switch self {

        case .unableToCreateDirectory:
            return
                "The notes and reviews storage folder could not be created."

        case .unableToEncode:
            return
                "Notes and reviews could not be prepared for saving."

        case .unableToDecode:
            return
                "Saved notes and reviews could not be read."

        case .unableToSave:
            return
                "Notes and reviews could not be saved."
        }
    }
}

final class LocalBookContentDataSource {
    let scope: AccountStorageScope?


    private let fileManager:
        FileManager

    private let encoder:
        JSONEncoder

    private let decoder:
        JSONDecoder

    init(
        fileManager:
            FileManager = .default,
        scope: AccountStorageScope? = nil
    ) {
        self.scope = scope
        self.fileManager =
            fileManager

        self.encoder =
            JSONEncoder()

        self.encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        self.decoder =
            JSONDecoder()
    }

    // MARK: - Load

    func loadContent()
        throws -> BookContentData
    {
        let fileURL =
            try contentFileURL()

        guard fileManager
            .fileExists(
                atPath:
                    fileURL.path
            )
        else {
            return .empty
        }

        do {
            let data =
                try Data(
                    contentsOf:
                        fileURL
                )

            return try decoder
                .decode(
                    BookContentData.self,
                    from: data
                )

        } catch let error
            as DecodingError
        {
            print(
                "❌ Book content decoding error:",
                error
            )

            throw LocalBookContentError
                .unableToDecode

        } catch {
            throw error
        }
    }

    // MARK: - Save

    func saveContent(
        _ content:
            BookContentData
    ) throws {

        let fileURL =
            try contentFileURL()

        do {
            let data =
                try encoder.encode(
                    content
                )

            try data.write(
                to: fileURL,
                options: .atomic
            )

        } catch is EncodingError {

            throw LocalBookContentError
                .unableToEncode

        } catch {

            throw LocalBookContentError
                .unableToSave
        }
    }

    // MARK: - File URL

    private func contentFileURL()
        throws -> URL
    {
        if let scope {
            try scope.checkAccess()
            try fileManager.createDirectory(at: scope.directory, withIntermediateDirectories: true)
            return scope.directory.appendingPathComponent("book-content.json")
        }

        guard let supportURL =
            fileManager.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            ).first
        else {
            throw LocalBookContentError
                .unableToCreateDirectory
        }

        let folder =
            supportURL
                .appendingPathComponent(
                    "BookApp",
                    isDirectory: true
                )

        if !fileManager
            .fileExists(
                atPath:
                    folder.path
            )
        {
            do {
                try fileManager
                    .createDirectory(
                        at: folder,
                        withIntermediateDirectories:
                            true
                    )
            } catch {
                throw LocalBookContentError
                    .unableToCreateDirectory
            }
        }

        return folder
            .appendingPathComponent(
                "book-content.json",
                isDirectory: false
            )
    }
}
