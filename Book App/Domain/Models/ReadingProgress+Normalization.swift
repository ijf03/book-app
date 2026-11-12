import Foundation

extension ReadingProgress {
    /// Percentage is the shared position. Missing denominators stay unknown.
    func normalizedFraction(pageCount: Int?, audioDuration: Int?) -> Double? {
        if let percentage, percentage.isFinite, (0...100).contains(percentage) {
            return percentage / 100
        }
        if let page, let pageCount, pageCount > 0, (0...pageCount).contains(page) {
            return Double(page) / Double(pageCount)
        }
        if let timestampSeconds, let audioDuration, audioDuration > 0,
           (0...audioDuration).contains(timestampSeconds) {
            return Double(timestampSeconds) / Double(audioDuration)
        }
        return nil
    }

    static func parseTime(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, let hours = Int(parts[0]), let minutes = Int(parts[1]),
              let seconds = Int(parts[2]), (0...100_000).contains(hours),
              (0..<60).contains(minutes), (0..<60).contains(seconds) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    static func timeText(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
