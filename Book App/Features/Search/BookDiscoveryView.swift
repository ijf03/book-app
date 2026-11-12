import SwiftUI

struct BookDiscoveryView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let model: BookDiscoveryViewModel
    let library: LibraryStore
    @Environment(BookContentStore.self) private var content: BookContentStore?
    @Environment(ReadingSessionStore.self) private var sessions: ReadingSessionStore?
    @State private var retry = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if model.isLoading {
                    if model.shelves.isEmpty {
                        SwiftUI.ProgressView("Finding books for you…")
                    } else {
                        SwiftUI.ProgressView("Loading book synopses…")
                    }
                }
                if !model.featured.isEmpty {
                    DiscoveryRecommendationsSection(
                        title: "Featured reads", recommendations: model.featured, library: library
                    )
                }
                ForEach(model.shelves) { shelf in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(shelf.title).font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: AppSpacing.md) {
                                ForEach(shelf.books) { book in
                                    NavigationLink {
                                        SearchBookDetailView(book: book, libraryStore: library)
                                    } label: {
                                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                            BookCoverView(url: book.coverURL, contentMode: .fit)
                                            Text(book.genreChips.first ?? String(localized: "Genre unavailable"))
                                                .font(AppTypography.caption)
                                                .foregroundStyle(Color.appAccent)
                                            Text(book.title).font(AppTypography.headline)
                                                .foregroundStyle(Color.textPrimary).lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                                            Text(book.authorText).font(AppTypography.caption)
                                                .foregroundStyle(Color.textSecondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    // Two full cards plus half of the next card cue horizontal scrolling.
                                    .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                                        typeSize.isAccessibilitySize ? width : max(1, (width - 2 * AppSpacing.md) / 2.5)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(book.title), \(book.authorText). View book details.")
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }
                }
                if !model.moreToExplore.isEmpty {
                    DiscoveryRecommendationsSection(
                        title: "Beyond the cover", recommendations: model.moreToExplore, library: library, loadsOnDemand: true
                    )
                }
                if let error = model.error {
                    Text(error).font(AppTypography.body).foregroundStyle(Color.textSecondary)
                    Button("Retry suggestions") { retry += 1 }
                        .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(model.isLoading)
                } else if !model.isLoading && model.shelves.isEmpty {
                    ContentUnavailableView("Try another genre", systemImage: "books.vertical",
                                           description: Text("No new suggestions were found. Choose another genre or search above."))
                }
                Button { retry += 1 } label: {
                    Label("Refresh suggestions", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                Text("Suggestions use your reading history, ratings and completion patterns, or the genre you choose. When there are no personalised matches, we offer classics to explore. Synopses are supplied by Open Library and may be unavailable. Books already in your library are hidden.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .task(id: "\(model.topic)-\(library.books.hashValue)-\(content?.reviews.hashValue ?? 0)-\(sessions?.sessions.hashValue ?? 0)-\(retry)") {
            await model.load(books: library.books, scope: library.accountScope, force: retry > 0, sessions: sessions?.sessions ?? [], reviews: content?.reviews ?? [])
        }
    }
}
