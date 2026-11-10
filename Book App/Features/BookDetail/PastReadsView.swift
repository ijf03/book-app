import SwiftUI

struct PastReadsView: View {
    let bookID: String
    @State private var isAddingRead = false
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(ReadingSessionStore.self) private var sessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let book = libraryStore.book(id: bookID) {
                    let reads = PastReadsPresentation.rows(book: book, sessions: sessionStore.sessions)
                    if reads.isEmpty {
                        ContentUnavailableView("No past reads yet", systemImage: "book.closed",
                                               description: Text("Completed reads will appear here."))
                    }
                    ForEach(reads) { read in
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text(read.dates).font(AppTypography.headline)
                                if read.usesSessionStart {
                                    Text("Start is the first recorded session.")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Previous sessions remain in your reading statistics. Starting a reread resets only the new read’s progress and timer.")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .sheet(isPresented: $isAddingRead) {
            AddPastReadView(bookID: bookID)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add past read", systemImage: "plus") { isAddingRead = true }
                    .tint(Color.appAccent)
            }
        }
        .navigationTitle("Past reads")
        .navigationBarTitleDisplayMode(.inline)
    }
}
