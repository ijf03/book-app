import SwiftUI

struct HomeView: View {

    @State
    private var viewModel: HomeViewModel

    init(
        store: LibraryStore
    ) {
        _viewModel = State(
            initialValue:
                HomeViewModel(
                    store: store
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
        VStack(
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {

            Text(
                "Your reading"
            )
            .font(
                AppTypography.body
            )
            .foregroundStyle(
                Color.textSecondary
            )

            Text(
                "Pick up where you left off."
            )
            .font(
                AppTypography.title
            )
            .foregroundStyle(
                Color.textPrimary
            )
        }
    }

    // MARK: - Reading Snapshot

    private var readingSnapshotSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Reading Snapshot"
            )

            HStack(
                spacing: AppSpacing.sm
            ) {

                summaryCard(
                    value:
                        viewModel.readingCount,
                    label:
                        "Reading",
                    systemImage:
                        "book.open"
                )

                summaryCard(
                    value:
                        viewModel.toReadCount,
                    label:
                        "To Read",
                    systemImage:
                        "bookmark"
                )

                summaryCard(
                    value:
                        viewModel.completedCount,
                    label:
                        "Completed",
                    systemImage:
                        "checkmark.circle"
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
                        "book.open"
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
            }
        )
    }

    // MARK: - Summary Card

    private func summaryCard(
        value: Int,
        label: String,
        systemImage: String
    ) -> some View {

        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {

                Image(
                    systemName:
                        systemImage
                )
                .foregroundStyle(
                    Color.appAccent
                )

                Text(
                    "\(value)"
                )
                .font(
                    AppTypography.title
                )
                .foregroundStyle(
                    Color.textPrimary
                )

                Text(
                    label
                )
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )
                .lineLimit(1)
                .minimumScaleFactor(
                    0.75
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
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
