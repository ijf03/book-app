import SwiftUI
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let signedIn: Bool
    let streak: Int
    let readToday: Bool

    static func make(date: Date, snapshot: [String: Any], calendar: Calendar = .current) -> Self {
        let last = snapshot["lastReadingDay"] as? Date
        let today = calendar.startOfDay(for: date)
        let age = last.flatMap { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day }
        let isCurrent = age == 0 || age == 1
        let signedIn = snapshot["signedIn"] as? Bool ?? false
        return Self(date: date, signedIn: signedIn,
                    streak: signedIn && isCurrent ? max(0, snapshot["streak"] as? Int ?? 0) : 0,
                    readToday: signedIn && age == 0)
    }
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        .init(date: Date(), signedIn: true, streak: 7, readToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : .make(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let value = snapshot
        let today = calendar.startOfDay(for: now)
        // Midnight entries age the streak even when the app hasn't been opened.
        let dates = [now] + (1...2).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = dates.map { StreakEntry.make(date: $0, snapshot: value, calendar: calendar) }
        completion(Timeline(entries: entries, policy: .after(dates.last ?? now.addingTimeInterval(86400))))
    }

    private var snapshot: [String: Any] {
        UserDefaults(suiteName: "group.edu.monash.BookApp")?
            .dictionary(forKey: "readingStreakSnapshot") ?? [:]
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Reading streak", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("AppAccent"))
            if entry.signedIn {
                Text(entry.streak, format: .number)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.streak == 1 ? "day in a row" : "days in a row")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
                Spacer(minLength: 0)
                Label(entry.readToday ? "Read today" : "Time to read",
                      systemImage: entry.readToday ? "checkmark.circle.fill" : "book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("AppAccent"))
            } else {
                Spacer(minLength: 0)
                Text("Open Book App")
                    .font(.headline)
                Text("Sign in to see your streak.")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(Color("TextPrimary"))
        .containerBackground(Color("Surface"), for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Book App.")
    }
}

struct ReadingStreakWidget: Widget {
    let kind = "ReadingStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading Streak")
        .description("Keep your reading habit going, one day at a time.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    ReadingStreakWidget()
} timeline: {
    StreakEntry(date: .now, signedIn: true, streak: 14, readToday: false)
    StreakEntry(date: .now, signedIn: true, streak: 14, readToday: true)
    StreakEntry(date: .now, signedIn: false, streak: 0, readToday: false)
}
