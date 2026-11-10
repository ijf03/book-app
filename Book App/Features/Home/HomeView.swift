import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var progressBook: Book?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    let onGoHome: () -> Void
    let onFindBooks: () -> Void
    let onShowProgress: () -> Void

    init(store: LibraryStore, sessionStore: ReadingSessionStore,
         onGoHome: @escaping () -> Void = {},
         onFindBooks: @escaping () -> Void = {},
         onShowProgress: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: HomeViewModel(store: store, sessionStore: sessionStore))
        self.onGoHome = onGoHome
        self.onFindBooks = onFindBooks
        self.onShowProgress = onShowProgress
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(viewModel.greeting).font(AppTypography.largeTitle)
                            Text("Keep your reading momentum going.")
                                .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image("AppLogo").resizable().scaledToFit()
                            .frame(width: AppLayout.minimumTapTarget, height: AppLayout.minimumTapTarget)
                            .accessibilityHidden(true)
                    }
                    HomeCheckInCard(model: viewModel)
                    currentlyReading
                    summary
                    HomeBookShelf(title: "Up next", books: Array(viewModel.upNextBooks.prefix(10)),
                                  empty: "Books marked To Read will appear here.", destination: detail)
                    HomeBookShelf(title: "Recently finished", books: Array(viewModel.completedBooks.prefix(10)),
                                  empty: "Your finished books will appear here.", destination: detail)
                    Button(action: onFindBooks) {
                        Label("Find your next read", systemImage: "magnifyingglass")
                    }.buttonStyle(AppButtonStyle(kind: .secondary))
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: AppLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.surfaceSecondary)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $progressBook) { book in
                NavigationStack {
                    UpdateProgressView(book: book, onSave: viewModel.updateBook)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { progressBook = nil } } }
                }
            }
            .task(id: viewModel.refreshKey) { await viewModel.refresh() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                // Refresh the greeting/day after foregrounding and while left open across midnight.
                while !Task.isCancelled {
                    await viewModel.refresh()
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                }
            }
        }
        .tint(Color.appAccent)
    }

    private var currentlyReading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Currently reading").font(AppTypography.title)
            if viewModel.currentlyReadingBooks.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Your next chapter starts here").font(AppTypography.headline)
                        Text("Move a book to Reading to track it here.").foregroundStyle(Color.textSecondary)
                        Button("Find a book", action: onFindBooks)
                    }
                }
            }
            ForEach(viewModel.currentlyReadingBooks.prefix(3)) { book in
                HomeReadingCard(book: book, onUpdate: { progressBook = book }, destination: { detail(book) })
            }
        }
    }

    private var summary: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.sm)) : AnyLayout(HStackLayout(spacing: AppSpacing.sm))
        return Button(action: onShowProgress) {
            layout {
                HomeSummaryTile(value: String(localized: "\(viewModel.currentStreak) days"), title: "reading streak")
                HomeSummaryTile(value: viewModel.yearlyTarget.map { "\(viewModel.yearlyCompleted) / \($0)" } ?? viewModel.yearlyCompleted.formatted(),
                                title: "books this year")
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens reading progress and goals.")
    }

    private func detail(_ book: Book) -> some View {
        BookDetailView(book: book, onBookUpdated: viewModel.updateBook,
                       onBookRemoved: { viewModel.removeBook(id: $0) }, onGoHome: onGoHome)
    }
}

private struct HomeCheckInCard: View {
    let model: HomeViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Today’s check-in").font(AppTypography.headline)
                    Text(model.didReadToday ? "You’ve read today. Well done!" : "Did you read today?")
                        .font(AppTypography.body).foregroundStyle(Color.onAccent)
                }
                Spacer()
                Text("\(model.currentStreak) day streak")
                    .font(AppTypography.caption).foregroundStyle(Color.appAccent)
                    .padding(AppSpacing.sm).background(Color.surface, in: Capsule())
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.sm)) : AnyLayout(HStackLayout(spacing: AppSpacing.sm))
            layout {
                Button { model.checkIn(true) } label: {
                    Label("Yes, I read", systemImage: "star.fill")
                }
                .buttonStyle(AppButtonStyle(kind: .onAccent))
                .overlay {
                    if model.didReadToday {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .strokeBorder(Color.appAccent, lineWidth: AppLayout.selectionOutlineWidth)
                            .padding(AppSpacing.xs)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityAddTraits(model.didReadToday ? .isSelected : [])
                .accessibilityIdentifier("home.checkIn.yes")
                Button { model.checkIn(false) } label: {
                    Label("Not today", systemImage: "xmark")
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
                .overlay {
                    if model.todayAnswer == false && !model.didReadToday {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .strokeBorder(Color.appAccent, lineWidth: AppLayout.selectionOutlineWidth)
                            .padding(AppSpacing.xs)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityAddTraits(model.todayAnswer == false && !model.didReadToday ? .isSelected : [])
                .accessibilityIdentifier("home.checkIn.no")
                .disabled(model.hasSessionToday)
            }
            if model.hasSessionToday {
                Text("Your finished session already counts for today.")
                    .font(AppTypography.caption).foregroundStyle(Color.onAccent)
            } else if model.todayAnswer == false {
                Text("There’s still time. You can check in later today.")
                    .font(AppTypography.caption).foregroundStyle(Color.onAccent)
            }
            Text("Check-ins count toward streaks, not recorded time or pages.")
                .font(AppTypography.caption).foregroundStyle(Color.onAccent)
            if let error = model.checkIns.error {
                Text(error).font(AppTypography.caption).foregroundStyle(Color.onAccent)
                Button("Retry loading check-ins") { model.checkIns.reload() }
            }
        }
        .padding(AppSpacing.md)
        .foregroundStyle(Color.onAccent)
        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

private struct HomeSummaryTile: View {
    let value: String
    let title: LocalizedStringResource
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(value).font(AppTypography.title).foregroundStyle(Color.appAccent)
            Text(title).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay { RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.border) }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeReadingCard<Destination: View>: View {
    let book: Book
    let onUpdate: () -> Void
    @ViewBuilder let destination: () -> Destination
    @Environment(\.dynamicTypeSize) private var typeSize
    private var fraction: Double? {
        if let percent = book.progress.percentage { return min(1, max(0, percent / 100)) }
        if let page = book.progress.page, let total = book.pageCount, total > 0 { return min(1, max(0, Double(page) / Double(total))) }
        return nil
    }
    var body: some View {
        AppCard {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md)) : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.md))
            layout {
                NavigationLink(destination: destination) {
                    BookCoverView(url: book.coverURL).frame(width: AppLayout.homeCoverWidth)
                }
                .accessibilityLabel("View \(book.title)")
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    NavigationLink(destination: destination) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(book.title).font(AppTypography.headline).foregroundStyle(Color.textPrimary)
                            Text(book.authorText).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                        }
                    }.buttonStyle(.plain)
                    if let fraction {
                        Text("\(Int(fraction * 100))% complete").font(AppTypography.caption).foregroundStyle(Color.appAccent)
                        SwiftUI.ProgressView(value: fraction).tint(Color.appAccent)
                            .accessibilityLabel("Reading progress")
                    } else { Text("Progress not recorded").font(AppTypography.caption).foregroundStyle(Color.textSecondary) }
                    Button(action: onUpdate) { Label("Update progress", systemImage: "arrow.right") }
                        .font(AppTypography.headline)
                        .frame(minHeight: AppLayout.minimumTapTarget)
                        .accessibilityLabel("Update progress for \(book.title)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct HomeBookShelf<Destination: View>: View {
    let title: LocalizedStringResource
    let books: [Book]
    let empty: LocalizedStringResource
    let destination: (Book) -> Destination
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title).font(AppTypography.title)
            if books.isEmpty {
                Text(empty).font(AppTypography.body).foregroundStyle(Color.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: AppSpacing.sm) {
                        ForEach(books) { book in
                            NavigationLink { destination(book) } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    BookCoverView(url: book.coverURL)
                                    Text(book.title).font(AppTypography.caption).foregroundStyle(Color.textPrimary).lineLimit(2)
                                }.frame(width: AppLayout.homeCoverWidth)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("View \(book.title)")
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
        }
    }
}


#Preview("Home redesign") {
    let scope = AccountStorageScope(directory: FileManager.default.temporaryDirectory.appendingPathComponent("home-preview-" + UUID().uuidString))
    let library = LibraryStore(books: [Book.mockFourthWing], localDataSource: LocalLibraryDataSource(scope: scope))
    let sessions = ReadingSessionStore(sessions: [], localDataSource: LocalReadingSessionDataSource(scope: scope))
    HomeView(store: library, sessionStore: sessions)
}
