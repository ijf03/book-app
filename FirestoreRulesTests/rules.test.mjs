import { before, after, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

let environment;
before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-book-tracker',
    firestore: { rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8') }
  });
});
after(async () => { await environment?.cleanup(); });
beforeEach(async () => { await environment.clearFirestore(); });

const hash = id => createHash('sha256').update(id).digest('hex');
const fixtures = {
  books: { id: '/works/OL123/W', data: { id: '/works/OL123/W', title: 'Book', authors: ['Author'], status: 'reading', format: 'audiobook', progress: { page: 3, percentage: 5, timestampSeconds: 60 }, coverURL: 'https://example.com/cover.jpg' } },
  sessions: { id: '11111111-1111-1111-1111-111111111111', data: { id: '11111111-1111-1111-1111-111111111111', bookID: '/works/OL123/W', startedAt: 700000000, totalPausedSeconds: 0, startProgress: {} } },
  notes: { id: '22222222-2222-2222-2222-222222222222', data: { id: '22222222-2222-2222-2222-222222222222', bookID: '/works/OL123/W', text: 'Note', containsSpoilers: false, createdAt: 700000000, updatedAt: 700000001 } },
  reviews: { id: '/works/OL123/W', data: { id: '33333333-3333-3333-3333-333333333333', bookID: '/works/OL123/W', rating: 4, text: 'Review', containsSpoilers: false, createdAt: 700000000, updatedAt: 700000001 } },
  goals: { id: '2026', data: { year: 2026, target: 12 } },
  lists: { id: '44444444-4444-4444-4444-444444444444', data: { id: '44444444-4444-4444-4444-444444444444', name: 'Favorites', description: '', bookIDs: ['/works/OL123/W'] } },
  preferences: { id: 'reminders', data: { isEnabled: true, hour: 20, minute: 30 } }
};
const envelope = (fixture, revision = 1) => ({ schemaVersion: 1, entityID: fixture.id, revision, operationID: randomUUID(), deleted: false, data: fixture.data, updatedAt: serverTimestamp() });
const reference = (database, kind, id, user = 'A') => doc(database, 'users', user, kind, hash(id));

for (const [kind, fixture] of Object.entries(fixtures)) {
  test(`${kind}: owner can create/read/query/update/tombstone; others and guests are denied`, async () => {
    const owner = environment.authenticatedContext('A').firestore();
    const other = environment.authenticatedContext('B').firestore();
    const guest = environment.unauthenticatedContext().firestore();
    const own = reference(owner, kind, fixture.id);
    await assertSucceeds(setDoc(own, envelope(fixture)));
    await assertSucceeds(getDoc(own));
    await assertSucceeds(getDocs(collection(owner, 'users', 'A', kind)));
    for (const client of [other, guest]) {
      const foreign = reference(client, kind, fixture.id);
      await assertFails(getDoc(foreign));
      await assertFails(getDocs(collection(client, 'users', 'A', kind)));
      await assertFails(setDoc(foreign, envelope(fixture, 2)));
      await assertFails(deleteDoc(foreign));
    }
    await assertFails(setDoc(own, envelope(fixture, 1)));
    await assertSucceeds(setDoc(own, envelope(fixture, 2)));
    await assertFails(deleteDoc(own));
    await assertSucceeds(setDoc(own, { ...envelope(fixture, 3), deleted: true, data: {} }));
    // Explicit restoration after observing a tombstone is allowed at the next revision.
    await assertSucceeds(setDoc(own, envelope(fixture, 4)));
  });
  test(`${kind}: invalid envelope/payload is denied`, async () => {
    const owner = environment.authenticatedContext('A').firestore();
    const own = reference(owner, kind, fixture.id);
    await assertFails(setDoc(own, { ...envelope(fixture), schemaVersion: 2 }));
    await assertFails(setDoc(own, { ...envelope(fixture), data: { invalid: true } }));
    await assertFails(setDoc(own, { ...envelope(fixture), updatedAt: 0 }));
    await assertFails(setDoc(own, { ...envelope(fixture), revision: 2 }));
    await assertFails(setDoc(own, { ...envelope(fixture), additionalField: true }));
    await assertFails(setDoc(own, { ...envelope(fixture), deleted: true }));
  });
}

test('both ordering preference documents are owner scoped', async () => {
  const owner = environment.authenticatedContext('A').firestore();
  for (const id of ['bookOrder', 'listOrder']) {
    const value = { id, data: { ids: ['/works/OL123/W', 'another-id'] } };
    await assertSucceeds(setDoc(reference(owner, 'preferences', id), envelope(value)));
  }
});

test('insight goals and genres allow owners, reject foreign writes and malformed fields', async () => {
  const owner = environment.authenticatedContext('A').firestore();
  const other = environment.authenticatedContext('B').firestore();
  for (const period of ['year', 'month', 'week']) {
    for (const metric of ['books', 'pages', 'days']) {
      const id = period === 'year' && metric === 'books' ? '2026' : `${period}-${metric}-2026-11-1`;
      const value = { id, data: { year: 2026, target: 30, period, metric, periodKey: '2026-11-1' } };
      await assertSucceeds(setDoc(reference(owner, 'goals', id), envelope(value)));
      await assertFails(setDoc(reference(other, 'goals', id), envelope(value, 2)));
    }
  }
  const invalid = { id: 'month-books-2026-11-1', data: { year: 2026, target: 30, period: 'day', metric: 'books', periodKey: '2026-11-1' } };
  await assertFails(setDoc(reference(owner, 'goals', invalid.id), envelope(invalid, 2)));
  const tagged = { ...fixtures.books, data: { ...fixtures.books.data, genre: 'Fantasy' } };
  await assertSucceeds(setDoc(reference(owner, 'books', tagged.id), envelope(tagged)));
  await assertFails(setDoc(reference(other, 'books', tagged.id), envelope(tagged, 2)));
  await assertFails(setDoc(reference(owner, 'books', tagged.id), envelope({ ...tagged, data: { ...tagged.data, genre: 123 } }, 2)));
  await assertFails(setDoc(reference(owner, 'books', tagged.id), envelope({ ...tagged, data: { ...tagged.data, genre: 'x'.repeat(101) } }, 2)));
});

test('unknown paths, nested collections, root user records, and invalid ranges are denied', async () => {
  const owner = environment.authenticatedContext('A').firestore();
  await assertFails(setDoc(doc(owner, 'users', 'A'), { admin: true }));
  await assertFails(setDoc(doc(owner, 'users', 'A', 'secrets', 'key'), { value: 'no' }));
  await assertFails(setDoc(doc(owner, 'users', 'A', 'books', hash('x'), 'nested', 'value'), {}));
  await assertFails(setDoc(doc(owner, 'books', 'public'), { value: 'no' }));
  await assertFails(setDoc(reference(owner, 'preferences', 'reminders'), envelope({ id: 'reminders', data: { isEnabled: true, hour: 24, minute: 0 } })));
  await assertFails(setDoc(reference(owner, 'reviews', '/works/OL123/W'), envelope({ ...fixtures.reviews, data: { ...fixtures.reviews.data, rating: 6 } })));
});

test('statistics metadata and immersive format are owner-only and validated', async () => {
  const owner = environment.authenticatedContext('A').firestore();
  const other = environment.authenticatedContext('B').firestore();
  const guest = environment.unauthenticatedContext().firestore();
  const book = { ...fixtures.books, data: { ...fixtures.books.data, format: 'immersive', bookType: 'fiction', language: 'English' } };
  const review = { ...fixtures.reviews, data: { ...fixtures.reviews.data, mood: 'Hopeful' } };
  for (const [kind, fixture] of [['books', book], ['reviews', review]]) {
    await assertSucceeds(setDoc(reference(owner, kind, fixture.id), envelope(fixture)));
    for (const client of [other, guest]) {
      await assertFails(getDoc(reference(client, kind, fixture.id)));
      await assertFails(setDoc(reference(client, kind, fixture.id), envelope(fixture, 2)));
    }
  }
  for (const invalid of [{ bookType: 'unknown' }, { language: 12 }, { language: 'x'.repeat(101) }, { format: 'video' }]) {
    await assertFails(setDoc(reference(owner, 'books', book.id), envelope({ ...book, data: { ...book.data, ...invalid } }, 2)));
  }
  for (const mood of [12, 'x'.repeat(101)]) {
    await assertFails(setDoc(reference(owner, 'reviews', review.id), envelope({ ...review, data: { ...review.data, mood } }, 2)));
  }
});

test('daily check-ins are owner-scoped and validate date identity and boolean answer', async () => {
  const owner = environment.authenticatedContext('A').firestore();
  const other = environment.authenticatedContext('B').firestore();
  const guest = environment.unauthenticatedContext().firestore();
  const fixture = { id: 'checkIn-2026-11-10', data: { day: '2026-11-10', didRead: true, recordedAt: 800000000 } };
  const own = reference(owner, 'preferences', fixture.id);
  await assertSucceeds(setDoc(own, envelope(fixture)));
  for (const client of [other, guest]) {
    await assertFails(getDoc(reference(client, 'preferences', fixture.id)));
    await assertFails(setDoc(reference(client, 'preferences', fixture.id), envelope(fixture, 2)));
  }
  for (const invalid of [{ didRead: 'yes' }, { day: '2026-11-11' }, { day: '2026-13-10' }, { recordedAt: 'today' }, { extra: true }]) {
    await assertFails(setDoc(own, envelope({ ...fixture, data: { ...fixture.data, ...invalid } }, 2)));
  }
  await assertSucceeds(setDoc(own, envelope({ ...fixture, data: { ...fixture.data, didRead: false } }, 2)));
});
