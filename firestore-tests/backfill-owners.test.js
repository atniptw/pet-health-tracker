// Tests for backfill-owners.js against the Firestore emulator. Run with
// `npm test` in this directory.
import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import { backfillOwners } from './backfill-owners.js';

const app = initializeApp({ projectId: 'demo-pet-health-tracker' }, 'backfill-owners-test');
const db = getFirestore(app);

const INVITE = 'a'.repeat(64);

async function household(id, data, members = {}) {
  await db.doc(`households/${id}`).set({ name: id, ...data });
  for (const [uid, member] of Object.entries(members)) {
    await db.doc(`households/${id}/members/${uid}`).set({ name: uid, ...member });
  }
}

const ownerOf = async (id) => (await db.doc(`households/${id}`).get()).get('ownerId');

beforeEach(async () => {
  await db.recursiveDelete(db.collection('households'));
});

after(async () => {
  await deleteApp(app);
});

test('makes a sole admin the owner', async () => {
  await household('h1', { memberIds: ['a', 'm'], adminIds: ['a'] });

  await backfillOwners(db, { apply: true });

  assert.equal(await ownerOf('h1'), 'a');
});

test('among several admins, picks the one who created the household', async () => {
  await household(
    'h1',
    { memberIds: ['joined', 'creator'], adminIds: ['joined', 'creator'] },
    {
      joined: { inviteId: INVITE, createdAt: Timestamp.fromMillis(1) },
      creator: { createdAt: Timestamp.fromMillis(2) },
    },
  );

  await backfillOwners(db, { apply: true });

  assert.equal(await ownerOf('h1'), 'creator');
});

test('when it is unclear who created it, picks the admin who has been there longest', async () => {
  await household(
    'h1',
    { memberIds: ['later', 'earlier'], adminIds: ['later', 'earlier'] },
    {
      later: { createdAt: Timestamp.fromMillis(2) },
      earlier: { createdAt: Timestamp.fromMillis(1) },
    },
  );

  await backfillOwners(db, { apply: true });

  assert.equal(await ownerOf('h1'), 'earlier');
});

test('falls back to the first admin when no admin has a member doc', async () => {
  await household('h1', { memberIds: ['b', 'a'], adminIds: ['b', 'a'] });

  await backfillOwners(db, { apply: true });

  assert.equal(await ownerOf('h1'), 'b');
});

test('leaves households that already have an owner alone', async () => {
  await household('h1', { memberIds: ['a', 'b'], adminIds: ['a', 'b'], ownerId: 'b' });

  const changes = await backfillOwners(db, { apply: true });

  assert.equal(await ownerOf('h1'), 'b');
  assert.deepEqual(changes, []);
});

test('only reports what it would do unless told to apply', async () => {
  await household('h1', { memberIds: ['a'], adminIds: ['a'] });

  const changes = await backfillOwners(db, { apply: false });

  assert.deepEqual(changes, [{ householdId: 'h1', ownerId: 'a' }]);
  assert.equal(await ownerOf('h1'), undefined);
});

test('changes nothing else on the household', async () => {
  const data = { memberIds: ['a'], adminIds: ['a'], updatedAt: Timestamp.fromMillis(5) };
  await household('h1', data);

  await backfillOwners(db, { apply: true });

  const { ownerId, ...rest } = (await db.doc('households/h1').get()).data();
  assert.equal(ownerId, 'a');
  assert.deepEqual(rest, { name: 'h1', ...data });
});
