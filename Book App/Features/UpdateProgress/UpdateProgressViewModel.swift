import Foundation
import Observation

@MainActor @Observable
final class UpdateProgressViewModel {
    enum Unit: String, CaseIterable, Identifiable {
        case page, percentage, timestamp
        var id: Self { self }
        var title: LocalizedStringResource {
            switch self { case .page: "Page"; case .percentage: "Percentage"; case .timestamp: "Audio timestamp" }
        }
    }

    let originalBook: Book
    var format: ReadingFormat {
        didSet { alignUnitWithFormat() }
    }
    var immersiveCompanion: ReadingFormat {
        didSet { if format == .immersive { alignUnitWithFormat() } }
    }
    var unit: Unit
    var pageText: String
    var percentageText: String
    var timestampText: String
    var pageCountText: String
    var audioDurationText: String

    init(book: Book) {
        originalBook = book
        format = book.format
        immersiveCompanion = book.immersiveCompanion == .ebook ? .ebook : .physical
        let fraction = book.progress.normalizedFraction(pageCount: book.pageCount, audioDuration: book.audioDurationSeconds)
        let pageFraction = ReadingProgress(page: book.progress.page, percentage: nil, timestampSeconds: nil)
            .normalizedFraction(pageCount: book.pageCount, audioDuration: nil)
        let audioFraction = ReadingProgress(page: nil, percentage: nil, timestampSeconds: book.progress.timestampSeconds)
            .normalizedFraction(pageCount: nil, audioDuration: book.audioDurationSeconds)
        // Keep explicit positions when they agree with the shared percentage.
        // Older records can contain stale positions from another format.
        if book.format == .audiobook, book.progress.timestampSeconds != nil, audioFraction == fraction {
            unit = .timestamp
        } else if book.progress.page != nil, pageFraction == fraction {
            unit = .page
        } else {
            unit = fraction != nil ? .percentage : book.format == .audiobook ? .timestamp : .page
        }
        if book.format == .immersive {
            unit = book.progress.page != nil || book.immersiveCompanion != .ebook ? .page : .percentage
        }
        pageText = book.progress.page.map(String.init) ?? ""
        percentageText = (book.format == .immersive ? book.immersiveReadingPercentage : nil).map { String($0) } ?? fraction.map { String($0 * 100) } ?? ""
        timestampText = book.progress.timestampSeconds.map(ReadingProgress.timeText) ?? ""
        pageCountText = book.pageCount.map(String.init) ?? ""
        audioDurationText = book.audioDurationSeconds.map(ReadingProgress.timeText) ?? ""
        alignUnitWithFormat()

    }

    var currentProgressFraction: Double {
        originalBook.progress.normalizedFraction(pageCount: originalBook.pageCount,
                                                audioDuration: originalBook.audioDurationSeconds) ?? 0
    }
    var currentProgressDescription: String {
        guard let fraction = originalBook.progress.normalizedFraction(pageCount: originalBook.pageCount,
                                                                      audioDuration: originalBook.audioDurationSeconds) else {
            return String(localized: "No shared progress recorded yet")
        }
        return fraction.formatted(.percent.precision(.fractionLength(1)))
    }
    var pageCount: Int? { Int(pageCountText) }
    var audioDuration: Int? { ReadingProgress.parseTime(audioDurationText) }

    var usesAudio: Bool { format == .audiobook || format == .immersive }
    var usesPages: Bool { unit == .page }
    var offersEbookUnits: Bool { format == .ebook || (format == .immersive && immersiveCompanion == .ebook) }

    private func alignUnitWithFormat() {
        switch format {
        case .physical: changeUnit(.page)
        case .audiobook: changeUnit(.timestamp)
        case .ebook:
            if unit == .timestamp { changeUnit(.percentage) }
        case .immersive:
            if immersiveCompanion == .physical { changeUnit(.page) }
            else if unit == .timestamp { changeUnit(.percentage) }
        }
    }

    var validationMessage: String? {
        if usesPages && pageCountText.isEmpty {
            return String(localized: "Enter the total pages once. We’ll remember it for this book.")
        }
        if usesAudio {
            guard let audioDuration, audioDuration > 0 else {
                return String(localized: "Enter the total audiobook duration as HH:MM:SS. We’ll remember it for this book.")
            }
            guard let position = ReadingProgress.parseTime(timestampText), position <= audioDuration else {
                return String(localized: "Enter an audio position as HH:MM:SS within the total duration.")
            }
        }
        if !pageCountText.isEmpty, pageCount == nil || (pageCount ?? 0) <= 0 || (pageCount ?? 0) > 1_000_000 {
            return String(localized: "Enter a total page count from 1 to 1,000,000.")
        }
        if !audioDurationText.isEmpty, audioDuration == nil || (audioDuration ?? 0) <= 0 {
            return String(localized: "Enter the total audiobook duration as HH:MM:SS, greater than zero.")
        }
        switch unit {
        case .page:
            guard let page = Int(pageText), page >= 0, page <= 1_000_000 else {
                return String(localized: "Enter a valid page number.")
            }
            if let pageCount, page > pageCount { return String(localized: "The page is beyond the end of this edition.") }
        case .percentage:
            guard let value = Double(percentageText), value.isFinite, (0...100).contains(value) else {
                return String(localized: "Enter a percentage between 0 and 100.")
            }
        case .timestamp:
            guard let seconds = ReadingProgress.parseTime(timestampText) else {
                return String(localized: "Enter the audio position as HH:MM:SS.")
            }
            if let audioDuration, seconds > audioDuration { return String(localized: "The audio position is beyond the total duration.") }
        }
        return nil
    }

    var hasPosition: Bool {
        if format == .immersive && !timestampText.isEmpty { return true }
        return switch unit {
        case .page: !pageText.isEmpty
        case .percentage: !percentageText.isEmpty
        case .timestamp: !timestampText.isEmpty
        }
    }
    var canSave: Bool { validationMessage == nil }
    var canSaveSession: Bool { canSave || (!hasPosition && pageCountText == (originalBook.pageCount.map(String.init) ?? "") && audioDurationText == (originalBook.audioDurationSeconds.map(ReadingProgress.timeText) ?? "")) }

    var enteredProgress: ReadingProgress {
        var progress = primaryProgress
        if format == .immersive {
            let seconds = ReadingProgress.parseTime(timestampText)
            let audioFraction = ReadingProgress(page: nil, percentage: nil, timestampSeconds: seconds)
                .normalizedFraction(pageCount: nil, audioDuration: audioDuration)
            let readingFraction = progress.normalizedFraction(pageCount: pageCount, audioDuration: nil)
            progress.timestampSeconds = seconds
            // Both positions belong to the same book: use the furthest, never add them.
            progress.percentage = [audioFraction, readingFraction].compactMap { $0 }.max().map { $0 * 100 }
        }
        return progress
    }

    private var primaryProgress: ReadingProgress {
        // Only explicitly entered pages become page records. Converted equivalents
        // are displayed below, but never inflate recorded-page statistics.
        switch unit {
        case .page:
            let page = Int(pageText)
            let fraction = page.flatMap { page in pageCount.map { Double(page) / Double($0) } }
            return .init(page: page, percentage: fraction.map { $0 * 100 }, timestampSeconds: nil)
        case .percentage:
            return .init(page: nil, percentage: Double(percentageText), timestampSeconds: nil)
        case .timestamp:
            let seconds = ReadingProgress.parseTime(timestampText)
            let fraction = seconds.flatMap { seconds in audioDuration.map { Double(seconds) / Double($0) } }
            return .init(page: nil, percentage: fraction.map { $0 * 100 }, timestampSeconds: seconds)
        }
    }

    var saveSummary: String {
        guard canSave else { return String(localized: "Enter a valid position to save.") }
        guard let fraction = enteredProgress.normalizedFraction(pageCount: pageCount, audioDuration: audioDuration) else {
            return String(localized: "Position saved. Add total pages or audio duration to calculate shared progress.")
        }
        return String(localized: "Shared progress: \(fraction.formatted(.percent.precision(.fractionLength(1))))")
    }

    var equivalents: String? {
        guard canSave, let fraction = enteredProgress.normalizedFraction(pageCount: pageCount, audioDuration: audioDuration) else { return nil }
        var parts: [String] = []
        if let pageCount { parts.append(String(localized: "About page \(Int((fraction * Double(pageCount)).rounded())) of \(pageCount)")) }
        if let audioDuration { parts.append(String(localized: "About \(ReadingProgress.timeText(Int((fraction * Double(audioDuration)).rounded()))) into the audiobook")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func changeUnit(_ newUnit: Unit) {
        guard newUnit != unit else { return }
        let fraction = primaryProgress.normalizedFraction(pageCount: pageCount, audioDuration: audioDuration)
        unit = newUnit
        guard let fraction else { return }
        switch newUnit {
        case .page:
            if let pageCount { pageText = String(Int((fraction * Double(pageCount)).rounded())) }
        case .percentage: percentageText = String(fraction * 100)
        case .timestamp:
            if let audioDuration { timestampText = ReadingProgress.timeText(Int((fraction * Double(audioDuration)).rounded())) }
        }
    }

    func makeUpdatedBook(allowEmptyProgress: Bool = false) -> Book? {
        guard canSave || (allowEmptyProgress && canSaveSession) else { return nil }
        var book = originalBook
        book.format = format
        book.immersiveCompanion = immersiveCompanion
        if format == .immersive && hasPosition {
            book.immersiveReadingPercentage = primaryProgress.percentage
        }
        book.pageCount = pageCount
        book.audioDurationSeconds = audioDuration
        book.progress = hasPosition ? enteredProgress : originalBook.progress
        if (book.progress.percentage ?? 0) >= 100 { book.status = .completed }
        return book
    }
}
