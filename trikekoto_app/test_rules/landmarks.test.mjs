// ============================================================
// Landmarks — places the chapter has named on the map
// ============================================================
// Everyone sees them, so a commuter or driver who could add one could send
// people anywhere. Admins write; anyone signed in reads.
// ============================================================

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  GeoPoint,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const ADMIN_EMAIL = 'admin@trikekoto.ph';

let testEnv;

const commuter = () =>
  testEnv
    .authenticatedContext('rider-1', {
      phone_number: '+639171234567',
      provider_id: 'phone',
    })
    .firestore();

const driver = () =>
  testEnv.authenticatedContext('driver-1', { email: 'driver@toda.ph' }).firestore();

const admin = () =>
  testEnv
    .authenticatedContext('admin-1', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const landmark = (overrides = {}) => ({
  name: 'TODA Terminal',
  point: new GeoPoint(14.6, 120.98),
  createdAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'trikekoto-landmarks-test',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'admins', ADMIN_EMAIL), { email: ADMIN_EMAIL }),
  );
});

describe('landmarks', () => {
  it('an admin can add one', async () => {
    await assertSucceeds(setDoc(doc(admin(), 'landmarks', 'l1'), landmark()));
  });

  it('a commuter or driver cannot', async () => {
    await assertFails(setDoc(doc(commuter(), 'landmarks', 'l1'), landmark()));
    await assertFails(setDoc(doc(driver(), 'landmarks', 'l1'), landmark()));
  });

  it('refuses one with no name, too long a name, or no real point', async () => {
    for (const bad of [
      { name: '' },
      { name: 'x'.repeat(81) },
      { point: 'Plaza' },
      { extra: true },
    ]) {
      await assertFails(setDoc(doc(admin(), 'landmarks', 'l1'), landmark(bad)));
    }
  });

  it('anyone signed in can read them, nobody signed out', async () => {
    await setDoc(doc(admin(), 'landmarks', 'l1'), landmark());
    await assertSucceeds(getDoc(doc(commuter(), 'landmarks', 'l1')));
    await assertSucceeds(getDoc(doc(driver(), 'landmarks', 'l1')));
    await assertFails(
      getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'landmarks', 'l1')),
    );
  });

  it('only an admin can remove one, and nobody edits one in place', async () => {
    await setDoc(doc(admin(), 'landmarks', 'l1'), landmark());
    await assertFails(deleteDoc(doc(commuter(), 'landmarks', 'l1')));
    await assertFails(updateDoc(doc(admin(), 'landmarks', 'l1'), { name: 'New' }));
    await assertSucceeds(deleteDoc(doc(admin(), 'landmarks', 'l1')));
  });
});
