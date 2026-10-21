import SwiftUI

struct LibraryView: View {

    @State
    private var viewModel:
        LibraryViewModel

    private let libraryStore: LibraryStore

    let onGoHome:
        () -> Void

    init(
        store: LibraryStore,
        onGoHome:
            @escaping () -> Void = {}
    ) {
        self.libraryStore = store
        _viewModel = State(
            initialValue:
                LibraryViewModel(
                    store: store
                )
        )

        self.onGoHome =
            onGoHome
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {

                    statusPicker

                    if viewModel.filteredBooks.isEmpty {
                        emptyState
                    } else {
                        bookContent
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("My Library")
            .toolbar {
                NavigationLink { CustomBookListsView(library: libraryStore) } label: { Label("Custom Lists", systemImage: "folder") }
            }
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search your library"
            )
        }
    }

    private var statusPicker: some View {
        Picker(
            "Reading Status",
            selection: $viewModel.selectedStatus
        ) {
            ForEach(ReadingStatus.allCases) { status in
                Text(status.displayName)
                    .tag(status)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var bookContent: some View {
        switch viewModel.selectedStatus {
        case .reading:
            readingList

        case .toRead, .completed:
            bookGrid
        }
    }

    private var readingList: some View {

        LazyVStack(
            spacing: AppSpacing.md
        ) {
            ForEach(
                viewModel.filteredBooks
            ) { book in

                NavigationLink {

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
    
    private var bookGrid: some View {

        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: 110
                    ),
                    spacing:
                        AppSpacing.md
                )
            ],
            spacing:
                AppSpacing.lg
        ) {

            ForEach(
                viewModel.filteredBooks
            ) { book in

                NavigationLink {

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
    }
    
    @ViewBuilder
    private var emptyState: some View {
        if viewModel.hasSearchQuery {
            ContentUnavailableView.search(
                text: viewModel.searchText
            )
            .padding(.top, AppSpacing.xxl)
        } else {
            ContentUnavailableView(
                "No Books",
                systemImage: "books.vertical",
                description: Text(
                    "There are no books in \(viewModel.selectedStatus.displayName)."
                )
            )
            .padding(.top, AppSpacing.xxl)
        }
    }
}

#Preview {
    LibraryView(
        store: LibraryStore(
            books: Book.mockBooks,
            localDataSource:
                LocalLibraryDataSource()
        )
    )
}
