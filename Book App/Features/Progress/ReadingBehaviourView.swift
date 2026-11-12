import SwiftUI

struct ReadingBehaviourPanel: View {
    let library: LibraryStore
    let sessions: ReadingSessionStore
    let content: BookContentStore
    @State private var profile = ReadingBehaviour()
    @State private var refresh = 0
    @Environment(\.scenePhase) private var scenePhase

    private var sourceKey: String {
        "\(library.books.hashValue)-\(sessions.sessions.hashValue)-\(content.reviews.hashValue)-\(refresh)"
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Your reading personality", systemImage: "sparkles").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                Text(profile.summary).font(AppTypography.body)
                Text("Generated from your own reading history. Updates as you read.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                NavigationLink("Explore your reading profile") {
                    ScrollView {
                        ReadingBehaviourDetails(profile: profile).padding(AppSpacing.md)
                            .frame(maxWidth: AppLayout.readableWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.surfaceSecondary)
                    .navigationTitle("Your reading profile")
                }
                .buttonStyle(.appSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: sourceKey) {
            guard library.accountScope?.isActive != false else { profile = ReadingBehaviour(); return }
            let input = StatisticsInput(books: library.books, sessions: sessions.sessions, reviews: content.reviews)
            let calculated = await Task.detached {
                ReadingBehaviourCalculator.calculate(input)
            }.value
            guard !Task.isCancelled, library.accountScope?.isActive != false else { return }
            profile = calculated
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh += 1 }
        }
    }
}

struct ReadingBehaviourDetails: View {
    let profile: ReadingBehaviour

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Reading behaviour · all history").font(AppTypography.title).accessibilityAddTraits(.isHeader)
            Text(profile.summary).font(AppTypography.body)
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    LabeledContent("Completed titles", value: profile.completed.formatted())
                    LabeledContent("Did not finish", value: profile.abandoned.formatted())
                    BehaviourMetric(title: "Average progress in current reads", value: profile.averageProgress,
                                    suffix: "%", samples: profile.progressSamples)
                    BehaviourMetric(title: "Average stopping point", value: profile.averageAbandonedProgress,
                                    suffix: "%", samples: profile.abandonedProgressSamples)
                    BehaviourMetric(title: "Typical finished book length", value: profile.medianFinishedPages,
                                    suffix: " pages", samples: profile.lengthSamples)
                    BehaviourMetric(title: "Average calendar days to finish", value: profile.averageDays,
                                    suffix: " days", samples: profile.durationSamples)
                    BehaviourMetric(title: "Average rating of completed titles", value: profile.averageCompletedRating,
                                    suffix: "/5", samples: profile.ratingSamples)
                }
            }
            if !profile.insights.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Patterns in your reading").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                        ForEach(profile.insights, id: \.self) { insight in
                            Label(insight, systemImage: "sparkles")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            Text("Genres you finish and leave unfinished").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
            if profile.genres.isEmpty {
                Text("Add genres to your books to see genre patterns.").foregroundStyle(Color.textSecondary)
            }
            ForEach(profile.genres) { BehaviourOutcomeCard(outcome: $0) }
            Text("Book length and completion").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
            ForEach(profile.lengths) { BehaviourOutcomeCard(outcome: $0) }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Formats you use").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                    ForEach(profile.formats) { format in
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(format.title).font(AppTypography.headline)
                            Text("\(format.completions) completed reads · \(format.sessions) recorded sessions")
                                .font(AppTypography.body)
                        }
                    }
                    Text("Completion format is the format saved when you finished. Session formats are recorded for new sessions; a session using multiple formats appears under each. Older sessions with no format stay unclassified.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("How to read these insights").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                    Text("These comparisons use your own history, not other readers. They describe patterns, not fixed preferences.")
                    Text("Completion rates use completed and did-not-finish titles only. Current reads and unread books are excluded from that rate. A previously completed title counts as completed even if a later attempt was stopped.")
                    Text("Typical length is the median of known page counts. Days to finish use recorded start and finish dates, or the first finished session when no start date exists; they are calendar days, not hours actively reading. Rereads count as separate timing samples.")
                    Text("\(profile.missingGenres) active or resolved titles lack genres; \(profile.missingLengths) lack page counts; \(profile.undatedCompletions) completed reads have no finish date.")
                    Text("Timing comparisons need at least two reads in each group. Length patterns need at least three known outcomes. Recent genre changes compare two 30-day windows with at least three tagged books each.")
                    Text("Recommendations consider genres, authors, completion outcomes, ratings and known book lengths. Missing metadata stays unknown; format availability is not inferred.")
                }
                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }
}

private struct BehaviourMetric: View {
    let title: LocalizedStringResource
    let value: Double?
    let suffix: String
    let samples: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppTypography.headline)
            if let value {
                Text(value.formatted(.number.precision(.fractionLength(1))) + suffix)
                Text("Based on \(samples) records").font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            } else {
                Text("Not enough recorded data").foregroundStyle(Color.textSecondary)
            }
        }
    }
}

private struct BehaviourOutcomeCard: View {
    let outcome: ReadingBehaviour.Outcome

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(outcome.title).font(AppTypography.headline)
                Text("\(outcome.completed) completed · \(outcome.abandoned) did not finish · \(outcome.reading) reading")
                if let rate = outcome.completionRate {
                    SwiftUI.ProgressView(value: rate).tint(Color.appAccent)
                        .accessibilityLabel("Completion rate")
                        .accessibilityValue(rate.formatted(.percent))
                    Text("\(rate.formatted(.percent.precision(.fractionLength(0)))) completion across \(outcome.resolved) resolved titles")
                        .font(AppTypography.caption)
                }
                if let days = outcome.averageDays {
                    Text("\(days.formatted(.number.precision(.fractionLength(1)))) days to finish · \(outcome.days.count) dated reads")
                        .font(AppTypography.caption)
                }
                if let rating = outcome.averageRating {
                    Text("\(rating.formatted(.number.precision(.fractionLength(1))))/5 average rating · \(outcome.ratings.count) completed titles rated")
                        .font(AppTypography.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
