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
  deleteField,
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
    [PET]: { name: 'Boogie', species: 'dog', createdAt: new Date(0), schemaVersion: 1 },
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

/** What the app writes when adding a pet (lib/data/pet.dart). */
function newPet(overrides = {}) {
  return {
    name: 'Pootz',
    species: 'cat',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
    ...overrides,
  };
}

/** [data] without [key], since the SDK rejects fields set to undefined. */
function without(data, key) {
  const { [key]: _, ...rest } = data;
  return rest;
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
    const rename = { name: 'x', updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(db(MEMBER), `${HOUSEHOLD}/pets/p2`), newPet()));
    await assertFails(updateDoc(doc(db(MEMBER), PET), rename));
    await assertFails(deleteDoc(doc(db(MEMBER), PET)));
    await assertSucceeds(setDoc(doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`), newPet()));
    await assertSucceeds(updateDoc(doc(db(ADMIN), PET), rename));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), PET)));
  });

  test('outsiders cannot add pets', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(OUTSIDER), `${HOUSEHOLD}/pets/p2`), newPet()));
  });

  test('a new pet can have every optional field', async () => {
    await seedHousehold();
    await assertSucceeds(
      setDoc(
        doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`),
        newPet({ breed: 'Tabby', birthDate: '2019-04-01', sex: 'female' }),
      ),
    );
  });

  test('a new pet needs a name of 1 to 100 characters', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`);
    await assertFails(setDoc(ref, newPet({ name: '' })));
    await assertFails(setDoc(ref, newPet({ name: 'x'.repeat(101) })));
    await assertFails(setDoc(ref, newPet({ name: 42 })));
    await assertFails(setDoc(ref, without(newPet(), 'name')));
    await assertSucceeds(setDoc(ref, newPet({ name: 'x'.repeat(100) })));
  });

  test('a new pet needs a known species', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`);
    await assertFails(setDoc(ref, newPet({ species: 'horse' })));
    await assertFails(setDoc(ref, without(newPet(), 'species')));
    await assertSucceeds(setDoc(ref, newPet({ species: 'other' })));
  });

  test('optional pet fields must be well formed', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`);
    await assertFails(setDoc(ref, newPet({ breed: 'x'.repeat(101) })));
    await assertFails(setDoc(ref, newPet({ breed: 7 })));
    await assertFails(setDoc(ref, newPet({ birthDate: '2019-4-1' })));
    await assertFails(setDoc(ref, newPet({ birthDate: new Date(0) })));
    await assertFails(setDoc(ref, newPet({ sex: 'neutered' })));
  });

  test('a new pet must use server timestamps, schema version 1, and not be archived', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`);
    await assertFails(setDoc(ref, newPet({ createdAt: new Date(0) })));
    await assertFails(setDoc(ref, newPet({ updatedAt: new Date(0) })));
    await assertFails(setDoc(ref, newPet({ schemaVersion: 2 })));
    await assertFails(setDoc(ref, newPet({ archivedAt: serverTimestamp() })));
  });

  test('a new pet cannot carry extra fields', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(ADMIN), `${HOUSEHOLD}/pets/p2`), newPet({ extra: true })));
  });

  test('a pet update must stamp updatedAt and keep createdAt', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), PET);
    await assertFails(updateDoc(ref, { name: 'x' }));
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { species: 'horse', updatedAt: serverTimestamp() }));
  });

  test('an admin edit can change every field and clear optional ones', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), PET);
    // What the app writes when editing a pet (lib/data/pet.dart).
    await assertSucceeds(
      updateDoc(ref, {
        name: 'Boogie Woogie',
        species: 'other',
        breed: 'Mutt',
        birthDate: '2018-02-03',
        sex: 'male',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(ref, {
        name: 'Boogie',
        species: 'dog',
        breed: deleteField(),
        birthDate: deleteField(),
        sex: deleteField(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('admins can archive a pet', async () => {
    await seedHousehold();
    await assertSucceeds(
      updateDoc(doc(db(ADMIN), PET), { archivedAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
  });
});

describe('symptom logs', () => {
  const LOG = `${PET}/symptomLogs/l1`;
  const NEW_LOG = `${PET}/symptomLogs/new`;
  const edit = { notes: 'Ate grass first', updatedAt: serverTimestamp() };

  async function seedLog(createdBy) {
    await seedHousehold();
    await seed({
      [LOG]: {
        symptom: 'other',
        title: 'Ate a sock',
        createdBy,
        occurredAt: new Date(0),
        createdAt: new Date(0),
        updatedAt: new Date(0),
        schemaVersion: 1,
      },
    });
  }

  /** What the app writes when logging a symptom (lib/data/symptom_log.dart). */
  function newLog(createdBy, overrides = {}) {
    return {
      symptom: 'other',
      title: 'Ate a sock',
      createdBy,
      occurredAt: new Date(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      schemaVersion: 1,
      ...overrides,
    };
  }

  test('members can read logs, outsiders cannot', async () => {
    await seedLog(MEMBER);
    await assertSucceeds(getDoc(doc(db(MEMBER), LOG)));
    await assertFails(getDoc(doc(db(OUTSIDER), LOG)));
  });

  test('members can create logs as themselves only', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), NEW_LOG);
    await assertFails(setDoc(ref, newLog(ADMIN)));
    await assertSucceeds(setDoc(ref, newLog(MEMBER)));
  });

  test('outsiders cannot create logs', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(OUTSIDER), NEW_LOG), newLog(OUTSIDER)));
  });

  test('a new log can have notes and answers', async () => {
    await seedHousehold();
    await assertSucceeds(
      setDoc(
        doc(db(MEMBER), NEW_LOG),
        newLog(MEMBER, { notes: 'Found chewing it around 2pm' }),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(db(MEMBER), `${PET}/symptomLogs/vomit`),
        without(newLog(MEMBER, { symptom: 'vomit', answers: { blood: true } }), 'title'),
      ),
    );
  });

  test('a new log needs a symptom key', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), NEW_LOG);
    await assertFails(setDoc(ref, without(newLog(MEMBER), 'symptom')));
    await assertFails(setDoc(ref, newLog(MEMBER, { symptom: '' })));
    await assertFails(setDoc(ref, newLog(MEMBER, { symptom: 'x'.repeat(51) })));
    await assertFails(setDoc(ref, newLog(MEMBER, { symptom: 3 })));
  });

  test('a title of 1 to 100 characters is required for other, and only for other', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), NEW_LOG);
    await assertFails(setDoc(ref, without(newLog(MEMBER), 'title')));
    await assertFails(setDoc(ref, newLog(MEMBER, { title: '' })));
    await assertFails(setDoc(ref, newLog(MEMBER, { title: 'x'.repeat(101) })));
    await assertFails(setDoc(ref, newLog(MEMBER, { symptom: 'vomit' })));
    await assertSucceeds(setDoc(ref, newLog(MEMBER, { title: 'x'.repeat(100) })));
  });

  test('optional log fields must be well formed', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), NEW_LOG);
    await assertFails(setDoc(ref, newLog(MEMBER, { notes: 'x'.repeat(2001) })));
    await assertFails(setDoc(ref, newLog(MEMBER, { notes: 7 })));
    await assertFails(setDoc(ref, newLog(MEMBER, { answers: 'blood' })));
    await assertFails(setDoc(ref, newLog(MEMBER, { occurredAt: '2026-10-05' })));
    await assertFails(setDoc(ref, without(newLog(MEMBER), 'occurredAt')));
    await assertSucceeds(setDoc(ref, newLog(MEMBER, { notes: 'x'.repeat(2000) })));
  });

  test('a new log must use server timestamps and schema version 1', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), NEW_LOG);
    await assertFails(setDoc(ref, newLog(MEMBER, { createdAt: new Date(0) })));
    await assertFails(setDoc(ref, newLog(MEMBER, { updatedAt: new Date(0) })));
    await assertFails(setDoc(ref, newLog(MEMBER, { schemaVersion: 2 })));
  });

  test('a new log cannot carry extra fields', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(MEMBER), NEW_LOG), newLog(MEMBER, { extra: true })));
  });

  test('members can edit and delete their own logs', async () => {
    await seedLog(MEMBER);
    await assertSucceeds(updateDoc(doc(db(MEMBER), LOG), edit));
    await assertSucceeds(deleteDoc(doc(db(MEMBER), LOG)));
  });

  test("members cannot edit or delete someone else's log", async () => {
    await seedLog(ADMIN);
    await assertFails(updateDoc(doc(db(MEMBER), LOG), edit));
    await assertFails(deleteDoc(doc(db(MEMBER), LOG)));
  });

  test("admins can edit and delete anyone's log", async () => {
    await seedLog(MEMBER);
    await assertSucceeds(updateDoc(doc(db(ADMIN), LOG), edit));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), LOG)));
  });

  test('nobody can change who created a log', async () => {
    await seedLog(MEMBER);
    const takeOver = { createdBy: ADMIN, updatedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(db(MEMBER), LOG), takeOver));
    await assertFails(updateDoc(doc(db(ADMIN), LOG), takeOver));
  });

  test('a log update must stamp updatedAt, keep createdAt, and stay valid', async () => {
    await seedLog(MEMBER);
    const ref = doc(db(MEMBER), LOG);
    await assertFails(updateDoc(ref, { notes: 'x' }));
    await assertFails(updateDoc(ref, { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { title: deleteField(), updatedAt: serverTimestamp() }));
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
