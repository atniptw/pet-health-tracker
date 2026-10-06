// Publishes assets/catalog/symptoms.json to the catalog/symptoms doc with the
// Admin SDK. Run it through scripts/publish-catalog.sh.
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

export const CATALOG_FILE = new URL('../assets/catalog/symptoms.json', import.meta.url);

/**
 * Every key and unit in the catalog, in the same form as
 * test/data/catalog_keys.txt: `vomit`, `vomit.content singleChoice`,
 * `vomit.content.food`, `seizure.durationSeconds unit seconds`.
 */
function keys(catalog) {
  return catalog.symptoms.flatMap((symptom) => [
    symptom.key,
    ...(symptom.questions ?? []).flatMap((question) => [
      `${symptom.key}.${question.key} ${question.type}`,
      ...(question.unit ? [`${symptom.key}.${question.key} unit ${question.unit}`] : []),
      ...(question.options ?? []).map((option) => `${symptom.key}.${question.key}.${option.key}`),
    ]),
  ]);
}

/**
 * Writes [catalog] to catalog/symptoms with the next catalog version, and
 * returns that version. Refuses if a key or unit that is already published
 * is missing or changed, which happens when publishing from an out-of-date
 * checkout.
 */
export async function publishCatalog(db, catalog) {
  const ref = db.doc('catalog/symptoms');
  return db.runTransaction(async (transaction) => {
    const published = (await transaction.get(ref)).data();
    if (published) {
      const kept = new Set(keys(catalog));
      const missing = keys(published).filter((key) => !kept.has(key));
      if (missing.length > 0) {
        throw new Error(
          `These published keys are missing or changed: ${missing.join(', ')}. ` +
            'Keys are never removed: retire them. Publish from an up-to-date checkout.',
        );
      }
    }
    const catalogVersion = (published?.catalogVersion ?? 0) + 1;
    transaction.set(ref, {
      catalogVersion,
      formatVersion: catalog.formatVersion,
      symptoms: catalog.symptoms,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return catalogVersion;
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const projectId = process.argv[2];
  if (!projectId) {
    console.error('Usage: node publish-catalog.js <project-id>');
    process.exit(1);
  }
  initializeApp({ credential: applicationDefault(), projectId });
  const catalog = JSON.parse(readFileSync(CATALOG_FILE, 'utf8'));
  const version = await publishCatalog(getFirestore(), catalog);
  console.log(`Published catalog version ${version} to ${projectId}.`);
}
