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
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const ADMIN = 'admin-uid';
const MEMBER = 'member-uid';
const OUTSIDER = 'outsider-uid';
const SECOND_ADMIN = 'second-admin-uid';

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

// Invite IDs are the SHA-256 hash of the code, in lowercase hex.
const INVITE_ID = 'a'.repeat(64);
const INVITE = `invites/${INVITE_ID}`;
const DAY_MS = 24 * 60 * 60 * 1000;

/** An invite to h1 made [ageDays] days ago, written directly. */
async function seedInvite(ageDays = 1, householdId = 'h1') {
  await seed({
    [INVITE]: {
      householdId,
      createdBy: ADMIN,
      createdAt: new Date(Date.now() - ageDays * DAY_MS),
      schemaVersion: 1,
    },
  });
}

/** What the app writes when making an invite. */
function newInvite(overrides = {}) {
  return {
    householdId: 'h1',
    createdBy: ADMIN,
    createdAt: serverTimestamp(),
    schemaVersion: 1,
    ...overrides,
  };
}

/** What the app writes for a member's name. */
function newMember(overrides = {}) {
  return {
    name: 'Tom',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
    ...overrides,
  };
}

/** The join batch: add [uid] to h1's memberIds and write their member doc. */
function join(uid, { inviteId = INVITE_ID, member = newMember({ inviteId }) } = {}) {
  const firestore = db(uid);
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, HOUSEHOLD), { memberIds: arrayUnion(uid), updatedAt: serverTimestamp() });
  batch.set(doc(firestore, `${HOUSEHOLD}/members/${uid}`), member);
  return batch.commit();
}

/** The leave write: remove [uid] from h1's memberIds. */
function leave(uid) {
  return updateDoc(doc(db(uid), HOUSEHOLD), {
    memberIds: arrayRemove(uid),
    updatedAt: serverTimestamp(),
  });
}

describe('joining a household', () => {
  test('a signed-in user can join with an unexpired invite', async () => {
    await seedHousehold();
    await seedInvite();
    await assertSucceeds(join(OUTSIDER));
    await assertSucceeds(getDoc(doc(db(OUTSIDER), HOUSEHOLD)));
  });

  test('an invite works for more than one person', async () => {
    await seedHousehold();
    await seedInvite();
    await assertSucceeds(join(OUTSIDER));
    await assertSucceeds(join('another-uid'));
  });

  test('an invite stops working 7 days after it was made', async () => {
    await seedHousehold();
    await seedInvite(7.01);
    await assertFails(join(OUTSIDER));
  });

  test('joining needs an invite that exists and points at this household', async () => {
    await seedHousehold();
    await assertFails(join(OUTSIDER));
    await seedInvite(1, 'h2');
    await assertFails(join(OUTSIDER));
  });

  test('joining needs the member doc in the same batch', async () => {
    await seedHousehold();
    await seedInvite();
    await assertFails(
      updateDoc(doc(db(OUTSIDER), HOUSEHOLD), {
        memberIds: arrayUnion(OUTSIDER),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('joining can only add yourself, as a member', async () => {
    await seedHousehold();
    await seedInvite();
    const firestore = db(OUTSIDER);
    const attempt = (changes) => {
      const batch = writeBatch(firestore);
      batch.update(doc(firestore, HOUSEHOLD), { updatedAt: serverTimestamp(), ...changes });
      batch.set(doc(firestore, `${HOUSEHOLD}/members/${OUTSIDER}`), newMember({ inviteId: INVITE_ID }));
      return batch.commit();
    };
    await assertFails(attempt({ memberIds: arrayUnion(OUTSIDER, 'friend-uid') }));
    await assertFails(attempt({ memberIds: arrayUnion(OUTSIDER), adminIds: arrayUnion(OUTSIDER) }));
    await assertFails(attempt({ memberIds: arrayUnion(OUTSIDER), name: 'Mine now' }));
    await assertFails(attempt({ memberIds: [OUTSIDER] }));
  });

  test('a former member can join again, keeping their member doc', async () => {
    await seed({
      [HOUSEHOLD]: { name: 'Home', memberIds: [ADMIN], adminIds: [ADMIN] },
      [`${HOUSEHOLD}/members/${MEMBER}`]: { name: 'Tom', createdAt: new Date(0), schemaVersion: 1 },
    });
    await seedInvite();
    await assertFails(join(MEMBER));
    await assertSucceeds(join(MEMBER, { member: newMember({ inviteId: INVITE_ID, createdAt: new Date(0) }) }));
  });
});

describe('leaving a household', () => {
  test('a member who is not an admin can leave', async () => {
    await seedHousehold();
    await assertSucceeds(leave(MEMBER));
    await assertFails(getDoc(doc(db(MEMBER), HOUSEHOLD)));
  });

  test('a member can only remove themselves', async () => {
    await seedHousehold();
    await seed({
      [HOUSEHOLD]: { name: 'Home', memberIds: [ADMIN, MEMBER, OUTSIDER], adminIds: [ADMIN] },
    });
    await assertFails(
      updateDoc(doc(db(MEMBER), HOUSEHOLD), { memberIds: arrayRemove(OUTSIDER), updatedAt: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(db(MEMBER), HOUSEHOLD), {
        memberIds: arrayRemove(MEMBER),
        name: 'Bye',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('outsiders have nothing to leave', async () => {
    await seedHousehold();
    await assertFails(leave(OUTSIDER));
  });

  test('the last admin cannot leave', async () => {
    await seedHousehold();
    await assertFails(
      updateDoc(doc(db(ADMIN), HOUSEHOLD), {
        memberIds: arrayRemove(ADMIN),
        adminIds: arrayRemove(ADMIN),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('admins cannot use the member leave path', async () => {
    await seed({
      [HOUSEHOLD]: { name: 'Home', memberIds: [ADMIN, SECOND_ADMIN], adminIds: [ADMIN, SECOND_ADMIN] },
    });
    await assertFails(leave(SECOND_ADMIN));
  });
});

describe('members', () => {
  const OWN = `${HOUSEHOLD}/members/${MEMBER}`;

  test('members can read member docs, outsiders cannot', async () => {
    await seedHousehold();
    await seed({ [OWN]: { name: 'Tom' } });
    await assertSucceeds(getDoc(doc(db(ADMIN), OWN)));
    await assertFails(getDoc(doc(db(OUTSIDER), OWN)));
  });

  test('a member can write their own name, not anyone else\'s', async () => {
    await seedHousehold();
    await assertSucceeds(setDoc(doc(db(MEMBER), OWN), newMember()));
    await assertFails(setDoc(doc(db(ADMIN), OWN), newMember({ createdAt: new Date(0) })));
    await assertFails(setDoc(doc(db(OUTSIDER), `${HOUSEHOLD}/members/${OUTSIDER}`), newMember()));
  });

  test('the creator can write their name in the batch that creates the household', async () => {
    const firestore = db(OUTSIDER);
    const batch = writeBatch(firestore);
    batch.set(doc(firestore, 'households/new'), newHousehold(OUTSIDER));
    batch.set(doc(firestore, `households/new/members/${OUTSIDER}`), newMember());
    await assertSucceeds(batch.commit());
  });

  test('a name is 1 to 100 characters', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), OWN);
    await assertFails(setDoc(ref, newMember({ name: '' })));
    await assertFails(setDoc(ref, newMember({ name: 'x'.repeat(101) })));
    await assertSucceeds(setDoc(ref, newMember({ name: 'x'.repeat(100) })));
  });

  test('a member doc must be well formed', async () => {
    await seedHousehold();
    const ref = doc(db(MEMBER), OWN);
    await assertFails(setDoc(ref, newMember({ createdAt: new Date(0) })));
    await assertFails(setDoc(ref, newMember({ schemaVersion: 2 })));
    await assertFails(setDoc(ref, newMember({ inviteId: 'not-a-hash' })));
    await assertFails(setDoc(ref, newMember({ extra: true })));
  });

  test('a member can rename themselves but not change createdAt', async () => {
    await seedHousehold();
    await seed({ [OWN]: { name: 'Tom', createdAt: new Date(0), schemaVersion: 1 } });
    const ref = doc(db(MEMBER), OWN);
    await assertSucceeds(updateDoc(ref, { name: 'Dad', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { createdAt: new Date(1), updatedAt: serverTimestamp() }));
  });

  test('nobody can delete a member doc', async () => {
    await seedHousehold();
    await seed({ [OWN]: { name: 'Tom' } });
    await assertFails(deleteDoc(doc(db(MEMBER), OWN)));
    await assertFails(deleteDoc(doc(db(ADMIN), OWN)));
  });

  test('a former member cannot change their name', async () => {
    await seed({
      [HOUSEHOLD]: { name: 'Home', memberIds: [ADMIN], adminIds: [ADMIN] },
      [OWN]: { name: 'Tom', createdAt: new Date(0), schemaVersion: 1 },
    });
    await assertFails(updateDoc(doc(db(MEMBER), OWN), { name: 'Dad', updatedAt: serverTimestamp() }));
  });
});

describe('invites', () => {
  test('any signed-in user can get an invite by its ID, signed-out users cannot', async () => {
    await seedInvite();
    await assertSucceeds(getDoc(doc(db(OUTSIDER), INVITE)));
    await assertFails(getDoc(doc(db(null), INVITE)));
  });

  test("only the household's admins can list its invites", async () => {
    await seedHousehold();
    await seedInvite();
    const invitesOf = (uid) => query(collection(db(uid), 'invites'), where('householdId', '==', 'h1'));
    await assertSucceeds(getDocs(invitesOf(ADMIN)));
    await assertFails(getDocs(invitesOf(MEMBER)));
    await assertFails(getDocs(invitesOf(OUTSIDER)));
    await assertFails(getDocs(collection(db(ADMIN), 'invites')));
  });

  test('only admins can make an invite for their household', async () => {
    await seedHousehold();
    await assertFails(setDoc(doc(db(MEMBER), INVITE), newInvite({ createdBy: MEMBER })));
    await assertFails(setDoc(doc(db(OUTSIDER), INVITE), newInvite({ createdBy: OUTSIDER })));
    await assertSucceeds(setDoc(doc(db(ADMIN), INVITE), newInvite()));
  });

  test('a new invite must be well formed', async () => {
    await seedHousehold();
    const ref = doc(db(ADMIN), INVITE);
    await assertFails(setDoc(doc(db(ADMIN), 'invites/purple-otter-lamp'), newInvite()));
    await assertFails(setDoc(ref, newInvite({ createdBy: MEMBER })));
    await assertFails(setDoc(ref, newInvite({ createdAt: new Date() })));
    await assertFails(setDoc(ref, newInvite({ schemaVersion: 2 })));
    await assertFails(setDoc(ref, newInvite({ expiresAt: new Date() })));
  });

  test('an unexpired code cannot be taken over, an expired one can', async () => {
    await seedHousehold();
    await seed({ 'households/h2': { name: 'Other', memberIds: [OUTSIDER], adminIds: [OUTSIDER] } });
    await seedInvite();
    const ref = doc(db(OUTSIDER), INVITE);
    const theirs = newInvite({ householdId: 'h2', createdBy: OUTSIDER });
    await assertFails(setDoc(ref, theirs));
    await seedInvite(8);
    await assertSucceeds(setDoc(ref, theirs));
  });

  test("only the household's admins can delete its invite", async () => {
    await seedHousehold();
    await seedInvite();
    await assertFails(deleteDoc(doc(db(MEMBER), INVITE)));
    await assertFails(deleteDoc(doc(db(OUTSIDER), INVITE)));
    await assertSucceeds(deleteDoc(doc(db(ADMIN), INVITE)));
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

  test('a catalog log can start with no answers', async () => {
    await seedHousehold();
    await assertSucceeds(
      setDoc(
        doc(db(MEMBER), NEW_LOG),
        without(newLog(MEMBER, { symptom: 'seizure', answers: {} }), 'title'),
      ),
    );
  });

  test('the author can set and remove single answers', async () => {
    await seedHousehold();
    await seed({
      [LOG]: {
        symptom: 'seizure',
        createdBy: MEMBER,
        answers: { urinated: true },
        occurredAt: new Date(0),
        createdAt: new Date(0),
        updatedAt: new Date(0),
        schemaVersion: 1,
      },
    });
    const answer = { 'answers.type': 'generalized', updatedAt: serverTimestamp() };
    const removal = { 'answers.urinated': deleteField(), updatedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(db(OUTSIDER), LOG), answer));
    await assertSucceeds(updateDoc(doc(db(MEMBER), LOG), answer));
    await assertSucceeds(updateDoc(doc(db(MEMBER), LOG), removal));
    await assertFails(updateDoc(doc(db(MEMBER), LOG), { 'answers.type': 'focal' }));
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
