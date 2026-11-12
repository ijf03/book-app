import SwiftUI

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel
    @State private var showsShelf = false
    @State private var showsGrid = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private let libraryStore: LibraryStore
    private let repository: any BookRepository
    let onGoHome: () -> Void
    let onFindBooks: () -> Void

    init(store: LibraryStore, repository: any BookRepository = DefaultBookRepository(remoteDataSource: OpenLibraryRemoteDataSource()), onGoHome: @escaping () -> Void = {}, onFindBooks: @escaping () -> Void = {}) {
        libraryStore = store
        self.repository = repository
        _viewModel = State(initialValue: LibraryViewModel(store: store))
        self.onGoHome = onGoHome
        self.onFindBooks = onFindBooks
    }

    var body: some View {
        NavigationStack {
            CustomBookListsView(library: libraryStore, isEmbedded: true, repository: repository) { status in
                viewModel.selectedStatus = status
                viewModel.searchText = ""
                showsShelf = true
            }
            .navigationDestination(isPresented: $showsShelf) {
                booksPage
                    .background(Color.surfaceSecondary)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(viewModel.selectedStatus?.displayName ?? String(localized: "All books"))
            }
        }
        .tint(Color.appAccent)
    }

    private var booksPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Your books, your shelves").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                        Text("\(viewModel.totalCount) books in your library")
                            .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Button(action: onFindBooks) { Label("Add books", systemImage: "plus") }
                    .buttonStyle(.appPrimary)
                    .accessibilityIdentifier("library.addBooks")
                ScrollView(.horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        filter("All books", count: viewModel.totalCount, status: nil)
                        filter("Reading", count: viewModel.count(for: .reading), status: .reading)
                        filter("To read", count: viewModel.count(for: .toRead), status: .toRead)
                        filter("Completed", count: viewModel.count(for: .completed), status: .completed)
                        filter("Did not finish", count: viewModel.count(for: .abandoned), status: .abandoned)
                    }
                }.scrollIndicators(.hidden)
                HStack {
                    Text("\(viewModel.filteredBooks.count) books")
                        .font(AppTypography.headline)
                    Spacer()
                    Menu {
                        Picker("Sort books", selection: $viewModel.sort) {
                            ForEach(LibraryViewModel.Sort.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .frame(minHeight: AppLayout.minimumTapTarget)
                    .accessibilityValue(Text(viewModel.sort.label))
                    if !typeSize.isAccessibilitySize {
                        Button { showsGrid.toggle() } label: {
                            Image(systemName: showsGrid ? "list.bullet" : "square.grid.2x2")
                                .frame(minWidth: AppLayout.minimumTapTarget, minHeight: AppLayout.minimumTapTarget)
                        }
                        .accessibilityLabel(showsGrid ? "Show as list" : "Show as grid")
                    }
                }
                if viewModel.filteredBooks.isEmpty {
                    emptyState
                } else if showsGrid && !typeSize.isAccessibilitySize {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: AppLayout.libraryCoverWidth), spacing: AppSpacing.md)], alignment: .leading, spacing: AppSpacing.lg) {
                        ForEach(viewModel.filteredBooks) { book in
                            bookLink(book) { LibraryShelfBook(book: book) }
                        }
                    }
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.filteredBooks) { book in
                            bookLink(book) { AppCard { BookRowCard(book: book) } }
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search title or author")
        .scrollDismissesKeyboard(.interactively)
    }

    private func filter(_ title: LocalizedStringResource, count: Int, status: ReadingStatus?) -> some View {
        Button { viewModel.selectedStatus = status } label: {
            HStack(spacing: AppSpacing.sm) {
                Text(title)
                Text(count.formatted()).monospacedDigit()
            }
            .font(AppTypography.headline)
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: AppLayout.minimumTapTarget)
            .background(viewModel.selectedStatus == status ? Color.accentTint : Color.surface, in: Capsule())
            .overlay { Capsule().stroke(viewModel.selectedStatus == status ? Color.appAccent : Color.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.selectedStatus == status ? Color.appAccent : Color.textPrimary)
        .accessibilityAddTraits(viewModel.selectedStatus == status ? .isSelected : [])
    }

    private func bookLink<Content: View>(_ book: Book, @ViewBuilder label: () -> Content) -> some View {
        NavigationLink {
            BookDetailView(book: book, onBookUpdated: viewModel.updateBook,
                           onBookRemoved: { viewModel.removeBook(id: $0) }, onGoHome: onGoHome)
        } label: { label() }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var emptyState: some View {
        if viewModel.hasSearchQuery {
            ContentUnavailableView.search(text: viewModel.searchText)
            Button("Clear search") { viewModel.searchText = "" }
                .buttonStyle(.appSecondary)
        } else {
            ContentUnavailableView("Your next read belongs here", systemImage: "books.vertical",
                description: Text(viewModel.totalCount == 0 ? "Find a book and add it to start your library." : "No books on this shelf yet. Choose another filter or add a book."))
        }
    }
}

private struct LibraryShelfBook: View {
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            BookCoverView(url: book.coverURL)
                .frame(height: AppLayout.libraryCoverWidth * 1.5)
                .clipped()
                .accessibilityHidden(true)
            Text(book.title).font(AppTypography.headline)
                .foregroundStyle(Color.textPrimary).lineLimit(2)
            Text(book.authorText).font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary).lineLimit(2)
            Text(LocalizedStringKey(book.status.displayName))
                .font(AppTypography.caption).foregroundStyle(Color.appAccent)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LibraryView(store: LibraryStore(books: Book.mockBooks, localDataSource: LocalLibraryDataSource()))
}
