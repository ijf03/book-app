import Foundation
import Testing
@testable import Book_App

@MainActor
struct ProgressNoteTests {
    @Test func optionalNotesValidateAndSaveWithBookPageSpoilersAndStableIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scope = AccountStorageScope(directory: directory)
        let local = try LocalSyncRepository(userID: "A", scope: scope)
        scope.syncRepository = local
        let source = LocalBookContentDataSource(scope: scope)
        let store = BookContentStore(notes: [], reviews: [], localDataSource: source)
        let draft = ProgressNoteDraft()
        #expect(draft.save(bookID: "book", page: 40, to: store))
        #expect(store.notes.isEmpty)
        draft.isEnabled = true
        draft.text = "  \n"
        #expect(!draft.canSave)
        #expect(!draft.save(bookID: "book", page: 40, to: store))
        draft.text = " A session thought "
        draft.containsSpoilers = true
        #expect(draft.save(bookID: "book", page: 40, to: store))
        let note = try #require(store.notes.first)
        #expect(note.bookID == "book")
        #expect(note.page == 40)
        #expect(note.text == "A session thought")
        #expect(note.containsSpoilers)
        #expect(local.pending.contains { $0.collection == .notes && $0.entityID == note.id.uuidString })
        draft.text = "Revised thought"
        #expect(draft.save(bookID: "book", page: nil, to: store))
        #expect(store.notes.count == 1)
        #expect(store.notes.first?.id == note.id)
        #expect(store.notes.first?.page == nil)
        #expect(try source.loadContent().notes == store.notes)
    }

    @Test func failedNoteSaveRetainsDraftAndDoesNotPublishUnsavedNote() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let store = BookContentStore(notes: [], reviews: [], localDataSource: .init(scope: scope))
        scope.invalidate()
        let draft = ProgressNoteDraft()
        draft.isEnabled = true
        draft.text = "Keep my draft"
        #expect(!draft.save(bookID: "book", page: 10, to: store))
        #expect(draft.text == "Keep my draft")
        #expect(draft.errorMessage != nil)
        #expect(store.notes.isEmpty)
    }
}
