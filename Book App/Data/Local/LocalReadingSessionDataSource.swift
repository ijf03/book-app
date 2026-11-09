//
//  LocalReadingSessionDataSource.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import Foundation

enum LocalReadingSessionError:
    LocalizedError
{
    case unableToCreateDirectory
    case unableToEncode
    case unableToSave
    case unableToDecode

    var errorDescription: String? {
        switch self {
        case .unableToCreateDirectory:
            return "The reading session storage folder could not be created."

        case .unableToEncode:
            return "Reading sessions could not be prepared for saving."

        case .unableToSave:
            return "Reading sessions could not be saved."

        case .unableToDecode:
            return "Saved reading sessions could not be read."
        }
    }
}

final class LocalReadingSessionDataSource {
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

    func loadSessions()
        throws -> [ReadingSession]
    {
        let fileURL =
            try sessionFileURL()

        guard fileManager.fileExists(
            atPath: fileURL.path
        ) else {
            print(
                "📖 No reading session file yet."
            )

            return []
        }

        do {
            let data =
                try Data(
                    contentsOf:
                        fileURL
                )

            let sessions =
                try decoder.decode(
                    [ReadingSession].self,
                    from: data
                )

            print(
                "✅ Loaded \(sessions.count) reading sessions."
            )

            return sessions

        } catch let error
            as DecodingError
        {
            print(
                "❌ Reading session decoding error:",
                error
            )

            throw LocalReadingSessionError
                .unableToDecode

        } catch {
            print(
                "❌ Reading session load error:",
                error
            )

            throw error
        }
    }

    // MARK: - Save

    func saveSessions(
        _ sessions:
            [ReadingSession]
    ) throws {

        let fileURL =
            try sessionFileURL()

        do {
            let data =
                try encoder.encode(
                    sessions
                )

            try data.write(
                to: fileURL,
                options: .atomic
            )

            print(
                "💾 Saved \(sessions.count) reading sessions."
            )

        } catch let error
            as EncodingError
        {
            print(
                "❌ Reading session encoding error:",
                error
            )

            throw LocalReadingSessionError
                .unableToEncode

        } catch {
            print(
                "❌ Reading session save error:",
                error
            )

            throw LocalReadingSessionError
                .unableToSave
        }
    }

    // MARK: - File Location

    private func sessionFileURL()
        throws -> URL
    {
        if let scope {
            try scope.checkAccess()
            try fileManager.createDirectory(at: scope.directory, withIntermediateDirectories: true)
            return scope.directory.appendingPathComponent("reading-sessions.json")
        }

        guard let supportURL =
            fileManager.urls(
                for:
                    .applicationSupportDirectory,
                in:
                    .userDomainMask
            ).first
        else {
            throw LocalReadingSessionError
                .unableToCreateDirectory
        }

        let folder =
            supportURL
                .appendingPathComponent(
                    "BookApp",
                    isDirectory: true
                )

        if !fileManager.fileExists(
            atPath: folder.path
        ) {
            do {
                try fileManager
                    .createDirectory(
                        at: folder,
                        withIntermediateDirectories:
                            true,
                        attributes: nil
                    )

            } catch {
                throw LocalReadingSessionError
                    .unableToCreateDirectory
            }
        }

        return folder
            .appendingPathComponent(
                "reading-sessions.json",
                isDirectory: false
            )
    }
}
