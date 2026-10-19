// Gives households made before owners an ownerId, with the Admin SDK. Run it
// through scripts/backfill-owners.sh.
import { pathToFileURL } from 'node:url';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

/**
 * The admin who most likely created [household]: a sole admin; else the
 * admin whose member doc has no invite (the creator), the earliest if
 * several; else the admin with the earliest member doc; else the first admin.
 */
async function likelyOwner(household) {
  const { adminIds } = household.data();
  if (adminIds.length === 1) return adminIds[0];

  const members = await household.ref.collection('members').get();
  const admins = members.docs
    .filter((member) => adminIds.includes(member.id))
    .sort((a, b) => (a.get('createdAt')?.toMillis() ?? 0) - (b.get('createdAt')?.toMillis() ?? 0));
  const creator = admins.find((member) => member.get('inviteId') === undefined);
  return (creator ?? admins[0])?.id ?? adminIds[0];
}

/**
 * Picks an owner for every household without one, and returns
 * `{householdId, ownerId}` for each. Writes them only when [apply] is true,
 * and only to households still without an owner.
 */
export async function backfillOwners(db, { apply }) {
  const changes = [];
  for (const household of (await db.collection('households').get()).docs) {
    if (household.get('ownerId') !== undefined) continue;
    const ownerId = await likelyOwner(household);
    changes.push({ householdId: household.id, ownerId });
    if (!apply) continue;
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(household.ref);
      if (current.get('ownerId') === undefined) transaction.update(household.ref, { ownerId });
    });
  }
  return changes;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [projectId, flag] = process.argv.slice(2);
  if (!projectId || (flag !== undefined && flag !== '--apply')) {
    console.error('Usage: node backfill-owners.js <project-id> [--apply]');
    process.exit(1);
  }
  initializeApp({ credential: applicationDefault(), projectId });
  const apply = flag === '--apply';
  const changes = await backfillOwners(getFirestore(), { apply });
  for (const { householdId, ownerId } of changes) console.log(`${householdId}: owner ${ownerId}`);
  console.log(
    apply
      ? `Set the owner of ${changes.length} households in ${projectId}.`
      : `${changes.length} households need an owner in ${projectId}. Run with --apply to set them.`,
  );
}
