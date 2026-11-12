import SwiftUI

struct InsightGenreEditor: View {
    let library: LibraryStore
    @State private var bookID = ""
    @State private var genre = ""
    @State private var bookType = ""
    @State private var language = ""
    @State private var format: ReadingFormat = .physical
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Book", selection: $bookID) {
                    Text("Choose a book").tag("")
                    ForEach(library.books) { Text($0.title).tag($0.id) }
                }
                Section("Reading details") {
                    TextField("Genres, separated by commas", text: $genre)
                        .textInputAutocapitalization(.words)
                    Picker("Book type", selection: $bookType) {
                        Text("Not recorded").tag("")
                        Text("Fiction").tag("fiction")
                        Text("Non-fiction").tag("nonfiction")
                    }
                    TextField("Language you read, for example English", text: $language)
                        .textInputAutocapitalization(.words)
                    Picker("Reading format", selection: $format) {
                        ForEach(ReadingFormat.allCases) { Text($0.displayName).tag($0) }
                    }
                    Text("Immersive reading means reading text while listening. Progress is recorded in pages. Language describes the edition you read, not the original language.")
                        .font(AppTypography.caption)
                }
                Text("Charts use your recorded details on dated completed books. Missing details stay Not recorded. Add your after-reading mood in the book review.")
                    .font(AppTypography.caption)
                if let error = library.persistenceError { Text(error) }
            }
            .navigationTitle("Book details for insights")
            .onChange(of: bookID) { _, id in
                guard let book = library.book(id: id) else { return }
                genre = book.genreChips.joined(separator: ", ")
                bookType = book.bookType ?? ""
                language = book.language ?? ""
                format = book.format
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Re-read so unrelated incoming edits are preserved.
                        guard var book = library.book(id: bookID) else { return }
                        let genre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
                        let language = language.trimmingCharacters(in: .whitespacesAndNewlines)
                        book.genres = GenreTags.normalized(genre.components(separatedBy: ","))
                        book.genre = book.genres?.first
                        book.language = language.isEmpty ? nil : language
                        book.bookType = bookType.isEmpty ? nil : bookType
                        book.format = format
                        library.updateBook(book)
                        if library.persistenceError == nil { dismiss() }
                    }.disabled(bookID.isEmpty || genre.count > 1000 || language.count > 100)
                }
            }
        }
    }
}
