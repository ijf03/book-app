import SwiftUI

struct BookDiscoveryView: View {
    let model: BookDiscoveryViewModel
    let library: LibraryStore
    @State private var retry = 0

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Discover your next read").font(AppTypography.title)
                    Text("Explore books from Open Library, including authors and genres in your reading history.")
                        .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                }
                Picker("Explore a genre", selection: $model.topic) {
                    ForEach(BookDiscoveryViewModel.topics, id: \.self) { topic in
                        Text(topic).tag(topic)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("search.discovery.genre")
                if model.isLoading {
                    SwiftUI.ProgressView("Finding books for you…")
                }
                ForEach(model.shelves) { shelf in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(shelf.title).font(AppTypography.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: AppSpacing.md) {
                                ForEach(shelf.books) { book in
                                    NavigationLink {
                                        SearchBookDetailView(book: book, libraryStore: library)
                                    } label: {
                                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                            BookCoverView(url: book.coverURL)
                                            Text(book.title).font(AppTypography.headline)
                                                .foregroundStyle(Color.textPrimary).lineLimit(3)
                                            Text(book.authorText).font(AppTypography.caption)
                                                .foregroundStyle(Color.textSecondary).lineLimit(2)
                                        }
                                        .frame(width: AppLayout.libraryCoverWidth, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(book.title), \(book.authorText). View book details.")
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }
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
                Text("Based on authors and genres you read. Books already in your library are hidden.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .task(id: "\(model.topic)-\(library.books.hashValue)-\(retry)") {
            await model.load(books: library.books, scope: library.accountScope, force: retry > 0)
        }
    }
}
