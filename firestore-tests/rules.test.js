// Security rules tests for firestore.rules. Run with `npm test` in this
// directory; it starts the Firestore emulator for the duration of the run.
import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, setLogLevel } from 'firebase/firestore';

// Denied requests are the point of these tests; don't log each one.
setLogLevel('silent');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pet-health-tracker',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8180,
    },
  });
});

after(async () => {
  await env.cleanup();
});

for (const [who, context] of [
  ['a signed-in user', () => env.authenticatedContext('some-uid')],
  ['a signed-out user', () => env.unauthenticatedContext()],
]) {
  test(`${who} can't read any document`, async () => {
    await assertFails(getDoc(doc(context().firestore(), 'anything/doc')));
  });

  test(`${who} can't write any document`, async () => {
    await assertFails(setDoc(doc(context().firestore(), 'anything/doc'), { a: 1 }));
  });
}
