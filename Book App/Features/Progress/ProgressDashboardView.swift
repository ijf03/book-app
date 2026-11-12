import SwiftUI

struct ProgressDashboardView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var statFontSize = 26
    @Environment(BookContentStore.self) private var contentStore: BookContentStore?
    private let repository: (any BookRepository)?
    private let reminders: ReadingRemindersViewModel
    
    private let libraryStore:
        LibraryStore

    private let sessionStore:
        ReadingSessionStore

    @State
    private var viewModel:
        ProgressDashboardViewModel

    init(
        libraryStore: LibraryStore,
        sessionStore:
            ReadingSessionStore,
        reminders: ReadingRemindersViewModel? = nil,
        repository: (any BookRepository)? = nil
    ) {
        self.repository = repository
        self.reminders = reminders ?? ReadingRemindersViewModel(repository: .init(fileName: "reading-reminders.json", scope: libraryStore.accountScope))
        self.libraryStore =
            libraryStore

        self.sessionStore =
            sessionStore

        _viewModel =
            State(
                initialValue:
                    ProgressDashboardViewModel(
                        libraryStore:
                            libraryStore,
                        sessionStore:
                            sessionStore
                    )
            )
    }
    
    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xl
                ) {

                    if let contentStore {
                        NavigationLink {
                            DetailedStatisticsView(library: libraryStore, sessions: sessionStore, content: contentStore, repository: repository)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(AppTypography.title)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text("View reading stats").font(AppTypography.title)
                                    Text("Explore your reading insights, streaks and pace")
                                        .font(AppTypography.caption)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right").accessibilityHidden(true)
                            }
                            .padding(.vertical, AppSpacing.md)
                        }
                        .buttonStyle(.appPrimary)
                        .accessibilityIdentifier("progress.detailedStats")
                    }

                    if let contentStore {
                        ReadingBehaviourPanel(library: libraryStore, sessions: sessionStore, content: contentStore)
                    }
                    InsightGoalView(library: libraryStore, sessions: sessionStore)

                    overviewSection



                    streakSection

                    activitySection

                    recentSessionsSection
                }
                .padding(
                    AppSpacing.md
                )
            }
            .background(
                Color.surfaceSecondary
            )
            .task(id: sessionStore.sessions) { await viewModel.refreshRecordedPages() }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(
                "Stats & Goals"
            )
            .toolbar {
                NavigationLink { ReadingRemindersSettingsView(model: reminders) } label: { Label("Notifications", systemImage: "bell") }
            }
        }
    }

    // MARK: - Overview

    private var overviewSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.md
        ) {

            SectionHeader(
                title:
                    "Reading Overview"
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm),
                               count: typeSize.isAccessibilitySize ? 1 : 2),
                spacing:
                    AppSpacing.sm
            ) {

                statCard(
                    title:
                        "Recorded Time",
                    value:
                        viewModel
                            .formattedReadingTime(
                                viewModel
                                    .totalReadingSeconds
                            ),
                    systemImage:
                        "clock"
                )

                statCard(
                    title:
                        "Sessions",
                    value:
                        "\(viewModel.totalSessionCount)",
                    systemImage:
                        "timer"
                )

                statCard(
                    title:
                        "Recorded Pages",
                    value:
                        "\(viewModel.totalPagesRead)",
                    systemImage:
                        "book.pages"
                )

                statCard(
                    title:
                        "Completed",
                    value:
                        "\(viewModel.completedBookCount)",
                    systemImage:
                        "checkmark.circle"
                )
            }
        }
    }

    // MARK: - Streak

    private var streakSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title:
                    "Reading Streak"
            )

            AppCard {

                HStack(
                    spacing:
                        AppSpacing.md
                ) {

                    ZStack {

                        RoundedRectangle(
                            cornerRadius:
                                AppRadius.md,
                            style:
                                .continuous
                        )
                        .fill(
                            Color.accentTint
                        )

                        Image(
                            systemName:
                                "flame"
                        )
                        .font(
                            .system(
                                size: 24,
                                weight:
                                    .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.appAccent
                        )
                    }
                    .frame(
                        width: 52,
                        height: 52
                    )

                    VStack(
                        alignment: .leading,
                        spacing:
                            AppSpacing.xs
                    ) {

                        Text(
                            streakTitle
                        )
                        .font(
                            AppTypography.title
                        )
                        .foregroundStyle(
                            Color.textPrimary
                        )

                        Text(
                            streakMessage
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                        NavigationLink {
                            ReadingRemindersSettingsView(model: reminders)
                        } label: {
                            Label("Set up reading reminders", systemImage: "bell.badge")
                        }
                        .buttonStyle(.appSecondary)
                        .accessibilityIdentifier("progress.setUpReminders")
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Activity

    private var activitySection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title:
                    "Last 7 Days"
            )

            AppCard {

                if viewModel
                    .weeklyActivity
                    .allSatisfy({
                        $0.seconds == 0
                    })
                {
                    emptyActivity

                } else {

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        if !typeSize.isAccessibilitySize {
                            weeklyChart.accessibilityHidden(true)
                            DisclosureGroup("Daily reading time as text") {
                                weeklyActivityText
                            }
                        } else {
                            weeklyActivityText
                        }
                    }
                }
            }
        }
    }

    private var weeklyActivityText: some View {
        ForEach(viewModel.weeklyActivity) { activity in
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(activity.date, format: .dateTime.weekday(.wide).month().day())
                Text(Duration.seconds(activity.seconds).formatted(
                    .units(allowed: [.hours, .minutes, .seconds], width: .wide)
                ))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var weeklyChart:
        some View
    {
        let maximumSeconds =
            max(
                viewModel
                    .weeklyActivity
                    .map(\.seconds)
                    .max() ?? 0,
                1
            )

        return HStack(
            alignment: .bottom,
            spacing: AppSpacing.sm
        ) {

            ForEach(
                viewModel
                    .weeklyActivity
            ) { activity in

                VStack(
                    spacing:
                        AppSpacing.xs
                ) {

                    Spacer(
                        minLength: 0
                    )

                    RoundedRectangle(
                        cornerRadius: 5,
                        style:
                            .continuous
                    )
                    .fill(
                        activity.seconds > 0
                        ? Color.appAccent
                        : Color.divider
                    )
                    .frame(
                        height:
                            barHeight(
                                seconds:
                                    activity
                                        .seconds,
                                maximumSeconds:
                                    maximumSeconds
                            )
                    )

                    Text(
                        weekdayText(
                            activity.date
                        )
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
            }
        }
        .frame(
            height: 170
        )
    }

    private var emptyActivity:
        some View
    {
        HStack(
            spacing: AppSpacing.md
        ) {

            Image(
                systemName:
                    "chart.bar"
            )
            .font(.title2)
            .foregroundStyle(
                Color.appAccent
            )

            VStack(
                alignment: .leading,
                spacing:
                    AppSpacing.xs
            ) {

                Text(
                    "No activity yet"
                )
                .font(
                    AppTypography.headline
                )
                .foregroundStyle(
                    Color.textPrimary
                )

                Text(
                    "Your completed reading sessions will appear here."
                )
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )
            }

            Spacer()
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            HStack {

                SectionHeader(
                    title:
                        "Recent Sessions"
                )

                Spacer()

                NavigationLink {
                    ReadingSessionHistoryView(
                        libraryStore:
                            libraryStore,
                        sessionStore:
                            sessionStore
                    )
                } label: {

                    HStack(
                        spacing:
                            AppSpacing.xs
                    ) {

                        Text("View All")

                        Image(
                            systemName:
                                "chevron.right"
                        )
                        .font(
                            .caption.weight(
                                .semibold
                            )
                        )
                    }
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.appAccent
                    )
                }
            }

            if viewModel
                .recentSessions
                .isEmpty
            {
                AppCard {

                    HStack(
                        spacing:
                            AppSpacing.md
                    ) {

                        Image(
                            systemName:
                                "timer"
                        )
                        .font(
                            .title2
                        )
                        .foregroundStyle(
                            Color.appAccent
                        )

                        VStack(
                            alignment:
                                .leading,
                            spacing:
                                AppSpacing.xs
                        ) {

                            Text(
                                "No sessions yet"
                            )
                            .font(
                                AppTypography.headline
                            )
                            .foregroundStyle(
                                Color.textPrimary
                            )

                            Text(
                                "Finish a reading session to start building your history."
                            )
                            .font(
                                AppTypography.caption
                            )
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }

                        Spacer()
                    }
                }

            } else {

                AppCard {

                    VStack(
                        spacing: 0
                    ) {

                        ForEach(
                            Array(
                                viewModel
                                    .recentSessions
                                    .enumerated()
                            ),
                            id:
                                \.element.id
                        ) {
                            index,
                            session in

                            recentSessionRow(
                                session
                            )

                            if index <
                                viewModel
                                    .recentSessions
                                    .count - 1
                            {
                                Divider()
                                    .padding(
                                        .leading,
                                        52 +
                                        AppSpacing.md
                                    )
                            }
                        }
                    }
                }
            }
        }
    }

    private func recentSessionRow(
        _ session:
            ReadingSession
    ) -> some View {

        HStack(
            spacing: AppSpacing.md
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius:
                        AppRadius.sm,
                    style:
                        .continuous
                )
                .fill(
                    Color.accentTint
                )

                Image(
                    systemName:
                        "book"
                )
                .foregroundStyle(
                    Color.appAccent
                )
            }
            .frame(
                width: 44,
                height: 44
            )

            VStack(
                alignment: .leading,
                spacing:
                    AppSpacing.xs
            ) {

                Text(
                    viewModel
                        .book(
                            for: session
                        )?
                        .title ??
                    "Reading Session"
                )
                .font(
                    AppTypography.headline
                )
                .foregroundStyle(
                    Color.textPrimary
                )
                .lineLimit(1)

                Text(
                    sessionSubtitle(
                        session
                    )
                )
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )
            }

            Spacer()

            Text(
                viewModel
                    .formattedReadingTime(
                        session
                            .elapsedSeconds(
                                at:
                                    session
                                        .endedAt ??
                                    Date()
                            )
                    )
            )
            .font(
                AppTypography.headline
            )
            .foregroundStyle(
                Color.appAccent
            )
            .monospacedDigit()
        }
        .padding(
            .vertical,
            AppSpacing.sm
        )
    }

    // MARK: - Stat Card

    private func statCard(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {

        AppCard {

            VStack(
                alignment: .leading,
                spacing:
                    AppSpacing.sm
            ) {

                Image(
                    systemName:
                        systemImage
                )
                .font(
                    .system(
                        size: 20,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    Color.appAccent
                )
                .frame(
                    width: 24,
                    height: 24
                )

                Text(value)
                    .font(
                        .system(
                            size: statFontSize,
                            weight:
                                .semibold,
                            design:
                                .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )
                    .monospacedDigit()

                Text(title)
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .leading
            )
            .frame(
                minHeight: 105
            )
        }
    }

    // MARK: - Helpers

    private var streakTitle:
        String
    {
        let streak =
            viewModel.currentStreak

        if streak == 0 {
            return "No current streak"
        }

        if streak == 1 {
            return "1 day"
        }

        return "\(streak) days"
    }

    private var streakMessage:
        String
    {
        if viewModel
            .currentStreak == 0
        {
            return
                "Complete a reading session to start a streak."
        }

        return
            "Keep reading to continue your streak."
    }

    private func barHeight(
        seconds: Int,
        maximumSeconds: Int
    ) -> CGFloat {

        guard seconds > 0
        else {
            return 8
        }

        let fraction =
            Double(seconds) /
            Double(maximumSeconds)

        return max(
            12,
            105 * fraction
        )
    }

    private func weekdayText(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter
            .dateFormat =
            "E"

        return formatter
            .string(
                from: date
            )
    }

    private func sessionSubtitle(
        _ session:
            ReadingSession
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.dateStyle =
            .medium

        formatter.timeStyle =
            .short

        let date =
            session.endedAt ??
            session.startedAt

        var parts: [String] = [
            formatter.string(
                from: date
            )
        ]

        if
            let startPage =
                session
                    .startProgress
                    .page,
            let endPage =
                session
                    .endProgress?
                    .page,
            endPage >= startPage
        {
            parts.append(
                "\(endPage - startPage) pages"
            )
        }

        return parts.joined(
            separator: " · "
        )
    }
}
