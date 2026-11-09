import SwiftUI

struct HomeView: View {

    @State
    private var viewModel: HomeViewModel
    
    let onGoHome:
        () -> Void
    
    init(
        store: LibraryStore,
        sessionStore:
            ReadingSessionStore,
        onGoHome:
            @escaping () -> Void =
                {}
    ) {
        _viewModel = State(
            initialValue:
                HomeViewModel(
                    store: store,
                    sessionStore:
                        sessionStore
                )
        )

        self.onGoHome =
            onGoHome
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xl
                ) {

                    welcomeSection

                    readingSnapshotSection

                    currentlyReadingSection

                    upNextSection

                    completedSection
                }
                .padding(
                    AppSpacing.md
                )
            }
            .background(
                Color.surfaceSecondary
            )
            .navigationTitle(
                "Home"
            )
        }
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                Text("Your reading")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textSecondary)
            }

            Text("Pick up where you left off.")
                .font(AppTypography.title)
                .foregroundStyle(Color.textPrimary)
        }
    }
    
    // MARK: - Reading Activity

    private var readingActivitySection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title:
                    "Reading Activity"
            )

            AppCard {

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {

                    HStack(
                        spacing: AppSpacing.md
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
                                    viewModel
                                        .currentStreak > 0
                                    ? "flame.fill"
                                    : "flame"
                            )
                            .font(
                                .system(
                                    size: 23,
                                    weight:
                                        .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.appAccent
                            )
                        }
                        .frame(
                            width: 50,
                            height: 50
                        )

                        VStack(
                            alignment: .leading,
                            spacing: AppSpacing.xs
                        ) {

                            Text(
                                streakHeadline
                            )
                            .font(
                                AppTypography.headline
                            )
                            .foregroundStyle(
                                Color.textPrimary
                            )

                            Text(
                                activitySubtitle
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

                    Divider()

                    HStack(
                        spacing: AppSpacing.md
                    ) {

                        activityMetric(
                            value:
                                viewModel
                                    .formattedTodayReadingTime,
                            label:
                                "Today",
                            systemImage:
                                "clock"
                        )

                        Divider()
                            .frame(
                                height: 42
                            )

                        activityMetric(
                            value:
                                "\(viewModel.todaySessionCount)",
                            label:
                                viewModel
                                    .todaySessionCount == 1
                                ? "Session"
                                : "Sessions",
                            systemImage:
                                "timer"
                        )
                    }
                }
            }
        }
    }

    private func activityMetric(
        value: String,
        label: String,
        systemImage: String
    ) -> some View {

        HStack(
            spacing: AppSpacing.sm
        ) {

            Image(
                systemName: systemImage
            )
            .font(
                .system(
                    size: 17,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.appAccent
            )
            .frame(
                width: 22
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {

                Text(value)
                    .font(
                        AppTypography.headline
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )
                    .monospacedDigit()

                Text(label)
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
            }

            Spacer()
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private var streakHeadline:
        String
    {
        switch viewModel.currentStreak {

        case 0:
            return "Start your reading streak"

        case 1:
            return "1 day reading streak"

        default:
            return
                "\(viewModel.currentStreak) day reading streak"
        }
    }

    private var activitySubtitle:
        String
    {
        if viewModel.todaySessionCount > 0 {
            return
                "You've already spent time reading today."
        }

        if viewModel.currentStreak > 0 {
            return
                "Read today to keep your streak going."
        }

        return
            "Finish a reading session to begin tracking activity."
    }

    // MARK: - Reading Snapshot

    private var readingSnapshotSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.md
        ) {
            SectionHeader(
                title: "Reading Snapshot"
            )

            HStack(
                alignment: .top,
                spacing: AppSpacing.sm
            ) {
                summaryCard(
                    title: "Reading",
                    count: viewModel.readingCount,
                    systemImage: "book"
                )

                summaryCard(
                    title: "To Read",
                    count: viewModel.toReadCount,
                    systemImage: "bookmark"
                )

                summaryCard(
                    title: "Completed",
                    count: viewModel.completedCount,
                    systemImage: "checkmark.circle"
                )
            }
        }
    }
    
    // MARK: - Currently Reading

    private var currentlyReadingSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Currently Reading"
            )

            if viewModel
                .currentlyReadingBooks
                .isEmpty
            {
                emptyCard(
                    title:
                        "Nothing in progress",
                    message:
                        "Move a book to Reading to see it here.",
                    systemImage:
                        "book"
                )

            } else {

                LazyVStack(
                    spacing: AppSpacing.md
                ) {
                    ForEach(
                        viewModel
                            .currentlyReadingBooks
                            .prefix(3)
                    ) { book in

                        NavigationLink {

                            bookDetailView(
                                for: book
                            )

                        } label: {

                            AppCard {
                                BookRowCard(
                                    book: book
                                )
                            }
                        }
                        .buttonStyle(
                            .plain
                        )
                    }
                }
            }
        }
    }

    // MARK: - Up Next

    private var upNextSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Up Next"
            )

            if viewModel
                .upNextBooks
                .isEmpty
            {
                emptyCard(
                    title:
                        "Your list is clear",
                    message:
                        "Books marked To Read will appear here.",
                    systemImage:
                        "bookmark"
                )

            } else {

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    LazyHStack(
                        alignment: .top,
                        spacing:
                            AppSpacing.md
                    ) {

                        ForEach(
                            viewModel
                                .upNextBooks
                                .prefix(6)
                        ) { book in

                            NavigationLink {

                                bookDetailView(
                                    for: book
                                )

                            } label: {

                                BookShelfItem(
                                    book: book
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        AppSpacing.xs
                    )
                }
            }
        }
    }

    // MARK: - Completed

    private var completedSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Completed"
            )

            if viewModel
                .completedBooks
                .isEmpty
            {
                emptyCard(
                    title:
                        "No completed books yet",
                    message:
                        "Finished books will appear here.",
                    systemImage:
                        "checkmark.circle"
                )

            } else {

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    LazyHStack(
                        alignment: .top,
                        spacing:
                            AppSpacing.md
                    ) {

                        ForEach(
                            viewModel
                                .completedBooks
                                .prefix(6)
                        ) { book in

                            NavigationLink {

                                bookDetailView(
                                    for: book
                                )

                            } label: {

                                BookShelfItem(
                                    book: book
                                )
                            }
                            .buttonStyle(
                                .plain
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        AppSpacing.xs
                    )
                }
            }
        }
    }

    // MARK: - Book Detail

    private func bookDetailView(
        for book: Book
    ) -> some View {

        BookDetailView(
            book: book,
            onBookUpdated: {
                updatedBook in

                viewModel.updateBook(
                    updatedBook
                )
            },
            onBookRemoved: {
                bookID in

                viewModel.removeBook(
                    id: bookID
                )
            },
            onGoHome: {
                onGoHome()
            }
        )
    }
    
    // MARK: - Summary Card

    private func summaryCard(
        title: String,
        count: Int,
        systemImage: String
    ) -> some View {

        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {

                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 22,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.appAccent
                )
                .frame(
                    width: 24,
                    height: 24,
                    alignment: .center
                )

                Text(
                    "\(count)"
                )
                .font(
                    .system(
                        size: 32,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color.textPrimary
                )

                Text(title)
                    .font(
                        AppTypography.body
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .frame(
                minHeight: 105
            )
        }
    }
    
    // MARK: - Empty Card

    private func emptyCard(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {

        AppCard {
            HStack(
                spacing: AppSpacing.md
            ) {

                Image(
                    systemName:
                        systemImage
                )
                .font(
                    .title2
                )
                .foregroundStyle(
                    Color.appAccent
                )

                VStack(
                    alignment: .leading,
                    spacing:
                        AppSpacing.xs
                ) {

                    Text(
                        title
                    )
                    .font(
                        AppTypography.headline
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )

                    Text(
                        message
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
    }
}
