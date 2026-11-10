//
//  UpdateProgressViewModel.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class UpdateProgressViewModel {

    let originalBook: Book

    var isPageEnabled: Bool
    var isPercentageEnabled: Bool
    var isTimestampEnabled: Bool

    var pageText: String
    var percentageText: String
    var timestampText: String

    init(book: Book) {
        self.originalBook = book

        pageText = book.progress.page.map(String.init) ?? ""

        if let percentage = book.progress.percentage {
            percentageText = Self.formatPercentage(percentage)
        } else {
            percentageText = ""
        }

        if let seconds = book.progress.timestampSeconds {
            timestampText = Self.formatTimestamp(seconds)
        } else {
            timestampText = ""
        }

        switch book.format {
        case .physical, .ebook, .immersive:
            isPageEnabled = true
            isPercentageEnabled = true
            isTimestampEnabled = false

        case .audiobook:
            isPageEnabled = false
            isPercentageEnabled = true
            isTimestampEnabled = true
        }
    }

    // MARK: - Current Progress

    var currentProgressFraction: Double {
        if let percentage = originalBook.progress.percentage {
            return min(max(percentage / 100, 0), 1)
        }

        if
            let page = originalBook.progress.page,
            let pageCount = originalBook.pageCount,
            pageCount > 0
        {
            return min(
                max(Double(page) / Double(pageCount), 0),
                1
            )
        }

        return 0
    }

    var currentProgressDescription: String {
        var parts: [String] = []

        if let page = originalBook.progress.page {
            if let pageCount = originalBook.pageCount {
                parts.append(
                    "Page \(page) of \(pageCount)"
                )
            } else {
                parts.append("Page \(page)")
            }
        }

        if let percentage = originalBook.progress.percentage {
            parts.append(
                "\(Self.formatPercentage(percentage))%"
            )
        }

        if let seconds = originalBook.progress.timestampSeconds {
            parts.append(Self.formatTimestamp(seconds))
        }

        if parts.isEmpty {
            return "No progress recorded yet"
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Bindings

    func updatePage(_ value: String) {
        pageText = value

        guard
            isPageEnabled,
            isPercentageEnabled,
            let page = Int(value),
            let pageCount = originalBook.pageCount,
            pageCount > 0
        else {
            return
        }

        let percentage =
            Double(page) /
            Double(pageCount) *
            100

        percentageText = Self.formatPercentage(
            min(max(percentage, 0), 100)
        )
    }

    func updatePercentage(_ value: String) {
        percentageText = value

        guard
            isPercentageEnabled,
            isPageEnabled,
            let percentage = Double(value),
            let pageCount = originalBook.pageCount,
            pageCount > 0
        else {
            return
        }

        let page = Int(
            (percentage / 100 * Double(pageCount))
                .rounded()
        )

        pageText = String(
            min(max(page, 0), pageCount)
        )
    }

    func updateTimestamp(_ value: String) {
        timestampText = value
    }

    // MARK: - Validation

    var validationMessage: String? {
        if
            isPageEnabled,
            !pageText.isEmpty
        {
            guard let page = Int(pageText) else {
                return "Page must be a whole number."
            }

            if page < 0 {
                return "Page cannot be negative."
            }

            if
                let pageCount = originalBook.pageCount,
                page > pageCount
            {
                return "Page cannot be greater than \(pageCount)."
            }
        }

        if
            isPercentageEnabled,
            !percentageText.isEmpty
        {
            guard let percentage = Double(percentageText) else {
                return "Percentage must be a number."
            }

            if percentage < 0 || percentage > 100 {
                return "Percentage must be between 0 and 100."
            }
        }

        if
            isTimestampEnabled,
            !timestampText.isEmpty,
            Self.parseTimestamp(timestampText) == nil
        {
            return "Timestamp must use HH:MM:SS."
        }

        return nil
    }

    var hasValueToSave: Bool {
        let hasPage =
            isPageEnabled &&
            !pageText.isEmpty

        let hasPercentage =
            isPercentageEnabled &&
            !percentageText.isEmpty

        let hasTimestamp =
            isTimestampEnabled &&
            !timestampText.isEmpty

        return hasPage ||
            hasPercentage ||
            hasTimestamp
    }

    var canSave: Bool {
        hasValueToSave &&
        validationMessage == nil
    }

    // MARK: - Save Summary

    var saveSummary: String {
        var parts: [String] = []

        if
            isPageEnabled,
            let page = Int(pageText)
        {
            if let pageCount = originalBook.pageCount {
                parts.append(
                    "Page \(page) of \(pageCount)"
                )
            } else {
                parts.append("Page \(page)")
            }
        }

        if
            isPercentageEnabled,
            let percentage = Double(percentageText)
        {
            parts.append(
                "\(Self.formatPercentage(percentage))%"
            )
        }

        if
            isTimestampEnabled,
            Self.parseTimestamp(timestampText) != nil
        {
            parts.append(timestampText)
        }

        if parts.isEmpty {
            return "Select at least one value to update."
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Saving

    func makeUpdatedBook() -> Book? {

        guard canSave else {
            return nil
        }

        var updatedBook =
            originalBook

        var progress =
            originalBook.progress

        if
            isPageEnabled,
            let page =
                Int(pageText)
        {
            progress.page =
                page
        }

        if
            isPercentageEnabled,
            let percentage =
                Double(
                    percentageText
                )
        {
            progress.percentage =
                percentage
        }

        if
            isTimestampEnabled,
            let seconds =
                Self.parseTimestamp(
                    timestampText
                )
        {
            progress.timestampSeconds =
                seconds
        }

        updatedBook.progress =
            progress

        if isCompleted(
            progress:
                progress,
            book:
                updatedBook
        ) {
            updatedBook.status =
                .completed
        }

        return updatedBook
    }

    private func isCompleted(
        progress: ReadingProgress,
        book: Book
    ) -> Bool {

        if let percentage =
            progress.percentage,
           percentage >= 100
        {
            return true
        }

        if
            let page =
                progress.page,
            let pageCount =
                book.pageCount,
            pageCount > 0,
            page >= pageCount
        {
            return true
        }

        return false
    }
    // MARK: - Formatting

    private static func formatPercentage(
        _ percentage: Double
    ) -> String {
        if percentage.rounded() == percentage {
            return String(Int(percentage))
        }

        return String(
            format: "%.1f",
            percentage
        )
    }

    private static func formatTimestamp(
        _ seconds: Int
    ) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }

    private static func parseTimestamp(
        _ value: String
    ) -> Int? {
        let components = value.split(
            separator: ":",
            omittingEmptySubsequences: false
        )

        guard components.count == 3 else {
            return nil
        }

        guard
            let hours = Int(components[0]),
            let minutes = Int(components[1]),
            let seconds = Int(components[2])
        else {
            return nil
        }

        guard
            hours >= 0,
            minutes >= 0,
            minutes < 60,
            seconds >= 0,
            seconds < 60
        else {
            return nil
        }

        return hours * 3600 +
            minutes * 60 +
            seconds
    }
}
