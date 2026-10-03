// Security rules tests for firestore.rules. Run with `npm test` in this
// directory; it starts the Firestore emulator for the duration of the run.
import { readFileSync } from 'node:fs';
import { after, afterEach, before, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
} from 'firebase/firestore';

const ADMIN = 'admin-uid';
const MEMBER = 'member-uid';
const OUTSIDER = 'outsider-uid';

const HOUSEHOLD = 'households/h1';
const PET = `${HOUSEHOLD}/pets/p1`;

// Denied writes are the point of half these tests; don't log each one.
setLogLevel('silent');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pet-health-tracker',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

afterEach(async () => {
  await env.clearFirestore();
});

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

/** Writes documents directly, bypassing the rules. */
async function seed(docs) {
  await env.withSecurityRulesDisabled(async (context) => {
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(context.firestore(), path), data);
    }
  });
}

async function seedHousehold() {
  await seed({
    [HOUSEHOLD]: { name: 'Home', memberIds: [ADMIN, MEMBER], adminIds: [ADMIN] },
    [PET]: { name: 'Boogie' },
  });
}

/** What the app writes when creating a household (lib/data/household.dart). */
function newHousehold(uid, overrides = {}) {
  return {
    name: 'Home',
    memberIds: [uid],
    adminIds: [uid],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
    ...overrides,
  };
}

describe('households', () => {
  test('members can read their household', async () => {
    await seedHousehold();
    await assertSucceeds(getDoc(doc(db(MEMBER), HOUSEHOLD)));
  });

  test('outsiders and signed-out users cannot read a household', async () => {
    await seedHousehold();
    await assertFails(getDoc(doc(db(OUTSIDER), HOUSEHOLD)));
    await assertFails(getDoc(doc(db(null), HOUSEHOLD)));
  });

  test('a signed-in user can create a household with only themselves in it', async () => {
    await assertSucceeds(setDoc(doc(db(OUTSIDER), 'households/new'), newHousehold(OUTSIDER)));
  });

  test('signed-out users cannot create a household', async () => {
    await assertFails(setDoc(doc(db(null), 'households/new'), newHousehold('anyone')));
  });

  test('a new household cannot add other members or admins', async () => {
    const ref = doc(db(OUTSIDER), 'households/new');
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { memberIds: [OUTSIDER, MEMBER] })));
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { adminIds: [MEMBER] })));
  });

  test('a new household needs a name of 1 to 100 characters', async () => {
    const ref = doc(db(OUTSIDER), 'households/new');
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { name: '' })));
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { name: 'x'.repeat(101) })));
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { name: 42 })));
    await assertSucceeds(setDoc(ref, newHousehold(OUTSIDER, { name: 'x'.repeat(100) })));
  });

  test('a new household must use server timestamps and schema version 1', async () => {
    const ref = doc(db(OUTSIDER), 'households/new');
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { createdAt: new Date(0) })));
    await assertFails(setDoc(ref, newHousehold(OUTSIDER, { schemaVersion: 2 })));
  });

  test('a new household cannot carry extra fields', async () => {
    await assertFails(
      setDoc(doc(db(OUTSIDER), 'households/new'), newHousehold(OUTSIDER, { extra: true })),
    );
  });

  test('only admins can update or delete a household', async () => {
    await seedHousehold();
    await assertFails(updateDoc(doc(db(MEMBER), HOUSEHOLD), { name: 'Mine now' }));
    await assertFails(deleteDoc(doc(db(MEMBER), HOUSEHOLD)));
    await assertSucceeds(updateDoc(doc(db(ADMIN), HOUSEHOLD), { name: 'Renamed' }));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), HOUSEHOLD)));
  });

  test('an update must keep at least one admin, and every admin a member', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), HOUSEHOLD);
    await assertFails(updateDoc(ref, { adminIds: [] }));
    await assertFails(updateDoc(ref, { adminIds: [ADMIN, OUTSIDER] }));
    await assertFails(updateDoc(ref, { memberIds: [MEMBER] }));
    await assertSucceeds(updateDoc(ref, { adminIds: [ADMIN, MEMBER] }));
  });
});

describe('pets', () => {
  test('members can read pets, outsiders cannot', async () => {
    await seedHousehold();
    await assertSucceeds(getDoc(doc(db(MEMBER), PET)));
    await assertFails(getDoc(doc(db(OUTSIDER), PET)));
  });

  test('only admins can add, change, or remove pets', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(MEMBER), `${HOUSEHOLD}/pets/p2`), { name: 'Pootz' }));
    await assertFails(updateDoc(doc(db(MEMBER), PET), { name: 'x' }));
    await assertFails(deleteDoc(doc(db(MEMBER), PET)));
    await assertSucceeds(setDoc(doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`), { name: 'Pootz' }));
    await assertSucceeds(updateDoc(doc(db(ADMIN), PET), { name: 'x' }));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), PET)));
  });
});

describe('symptom logs', () => {
  const LOG = `${PET}/symptomLogs/l1`;

  async function seedLog(createdBy) {
    await seedHousehold();
    await seed({ [LOG]: { createdBy, type: 'vomit' } });
  }

  test('members can read logs, outsiders cannot', async () => {
    await seedLog(MEMBER);
    await assertSucceeds(getDoc(doc(db(MEMBER), LOG)));
    await assertFails(getDoc(doc(db(OUTSIDER), LOG)));
  });

  test('members can create logs as themselves only', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), `${PET}/symptomLogs/new`);
    await assertSucceeds(setDoc(ref, { createdBy: MEMBER, type: 'vomit' }));
    await assertFails(setDoc(ref, { createdBy: ADMIN, type: 'vomit' }));
  });

  test('outsiders cannot create logs', async () => {
    await seedHousehold();
    await assertFails(
      setDoc(doc(db(OUTSIDER), `${PET}/symptomLogs/new`), { createdBy: OUTSIDER, type: 'vomit' }),
    );
  });

  test('members can edit and delete their own logs', async () => {
    await seedLog(MEMBER);
    await assertSucceeds(updateDoc(doc(db(MEMBER), LOG), { type: 'seizure' }));
    await assertSucceeds(deleteDoc(doc(db(MEMBER), LOG)));
  });

  test("members cannot edit or delete someone else's log", async () => {
    await seedLog(ADMIN);
    await assertFails(updateDoc(doc(db(MEMBER), LOG), { type: 'seizure' }));
    await assertFails(deleteDoc(doc(db(MEMBER), LOG)));
  });

  test("admins can edit and delete anyone's log", async () => {
    await seedLog(MEMBER);
    await assertSucceeds(updateDoc(doc(db(ADMIN), LOG), { type: 'seizure' }));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), LOG)));
  });

  test('nobody can change who created a log', async () => {
    await seedLog(MEMBER);
    await assertFails(updateDoc(doc(db(MEMBER), LOG), { createdBy: ADMIN }));
    await assertFails(updateDoc(doc(db(ADMIN), LOG), { createdBy: ADMIN }));
  });
});

describe('medications', () => {
  const MED = `${PET}/medications/m1`;

  test('members can read medications, outsiders cannot', async () => {
    await seedHousehold();
    await seed({ [MED]: { name: 'Gabapentin' } });
    await assertSucceeds(getDoc(doc(db(MEMBER), MED)));
    await assertFails(getDoc(doc(db(OUTSIDER), MED)));
  });

  test('only admins can write medications', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(MEMBER), MED), { name: 'Gabapentin' }));
    await assertSucceeds(setDoc(doc(db(ADMIN), MED), { name: 'Gabapentin' }));
  });
});

describe('catalog', () => {
  test('signed-in users can read the catalog, signed-out users cannot', async () => {
    await seed({ 'catalog/symptoms': { symptoms: [] } });
    await assertSucceeds(getDoc(doc(db(OUTSIDER), 'catalog/symptoms')));
    await assertFails(getDoc(doc(db(null), 'catalog/symptoms')));
  });

  test('nobody can write the catalog', async () => {
    await assertFails(setDoc(doc(db(ADMIN), 'catalog/symptoms'), { symptoms: [] }));
  });
});
