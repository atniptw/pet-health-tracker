// Tests for publish-catalog.js against the Firestore emulator. Run with
// `npm test` in this directory.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { after, beforeEach, test } from 'node:test';

import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import { CATALOG_FILE, publishCatalog } from './publish-catalog.js';

const app = initializeApp({ projectId: 'demo-pet-health-tracker' }, 'publish-catalog-test');
const db = getFirestore(app);
const ref = db.doc('catalog/symptoms');

const fileCatalog = JSON.parse(readFileSync(CATALOG_FILE, 'utf8'));

const catalog = (questions) => ({
  formatVersion: 1,
  symptoms: [{ key: 'vomit', label: 'Vomit', questions }],
});
const blood = { key: 'blood', label: 'Blood', type: 'yesNo' };
const content = {
  key: 'content',
  label: 'What came up',
  type: 'singleChoice',
  options: [{ key: 'food', label: 'Food' }],
};

beforeEach(async () => {
  await ref.delete();
});

after(async () => {
  await deleteApp(app);
});

test('publishes the catalog file as version 1', async () => {
  assert.equal(await publishCatalog(db, fileCatalog), 1);

  const published = (await ref.get()).data();
  assert.equal(published.catalogVersion, 1);
  assert.equal(published.formatVersion, fileCatalog.formatVersion);
  assert.deepEqual(published.symptoms, fileCatalog.symptoms);
  assert.ok(published.updatedAt instanceof Timestamp);
});

test('each publish bumps the catalog version', async () => {
  await publishCatalog(db, catalog([blood]));
  assert.equal(await publishCatalog(db, catalog([blood, content])), 2);

  const published = (await ref.get()).data();
  assert.equal(published.catalogVersion, 2);
  assert.deepEqual(published.symptoms[0].questions, [blood, content]);
});

test('refuses to drop keys that are already published', async () => {
  await publishCatalog(db, catalog([blood, content]));

  await assert.rejects(publishCatalog(db, catalog([blood])), /content singleChoice, vomit\.content\.food/);
  await assert.rejects(
    publishCatalog(db, catalog([blood, { ...content, options: [] }])),
    /vomit\.content\.food/,
  );
  assert.equal((await ref.get()).data().catalogVersion, 1);
});

test("refuses to change a published question's type", async () => {
  await publishCatalog(db, catalog([blood]));

  await assert.rejects(publishCatalog(db, catalog([{ ...blood, type: 'text' }])), /vomit\.blood yesNo/);
});
