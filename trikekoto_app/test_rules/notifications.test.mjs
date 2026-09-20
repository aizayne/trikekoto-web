// ============================================================
// TrikeKoTo — in-app notices against the security rules
// ============================================================
// A notice is worth something only because the system said it. These prove
// the two halves of that: no client can write one — not the owner, not an
// admin — and the owner's single power is to mark one read.
// ============================================================

import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-notices-test';
const DRIVER = 'juan@toda.ph';
const DRIVER_UID = 'driver-uid-1';
const RIVAL = 'pedro@toda.ph';
const RIVAL_UID = 'driver-uid-2';
const ADMIN_EMAIL = 'admin@trikekoto.ph';
const NOTICE = 'account_approved';

let testEnv;

const driver = (email = DRIVER, uid = DRIVER_UID) =>
  testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
const admin = () =>
  testEnv
    .authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const notices = (db, uid = DRIVER_UID) =>
  collection(db, 'notifications', uid, 'items');
const notice = (db, uid = DRIVER_UID, id = NOTICE) =>
  doc(db, 'notifications', uid, 'items', id);

// The screen's own query, as the app builds it.
const inbox = (db, uid = DRIVER_UID) =>
  query(notices(db, uid), orderBy('createdAt', 'desc'), limit(30));

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Written the way the function writes it — with rules disabled, which is
  // what a Cloud Function's admin credential amounts to here.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'admins', ADMIN_EMAIL), { email: ADMIN_EMAIL });
    await setDoc(notice(db), {
      type: NOTICE,
      title: 'Account approved',
      body: 'Your account has been approved by the admin. You can now log in.',
      createdAt: new Date(),
      readAt: null,
    });
    await setDoc(notice(db, RIVAL_UID), {
      type: NOTICE,
      title: 'Account approved',
      body: 'Your account has been approved by the admin. You can now log in.',
      createdAt: new Date(),
      readAt: null,
    });
  });
});

describe('in-app notices', () => {
  it('the owner reads their own', async () => {
    const snap = await assertSucceeds(getDocs(inbox(driver())));
    assert.deepEqual(snap.docs.map((d) => d.id), [NOTICE]);
    await assertSucceeds(getDoc(notice(driver())));
  });

  it("nobody reads somebody else's — not another driver, not an admin", async () => {
    await assertFails(getDocs(inbox(driver(RIVAL, RIVAL_UID), DRIVER_UID)));
    await assertFails(getDoc(notice(driver(RIVAL, RIVAL_UID), DRIVER_UID)));
    // An admin approves a driver; the function writes the notice. Reading
    // what a driver has been told is not part of that.
    await assertFails(getDocs(inbox(admin())));
  });

  it('the owner marks one read', async () => {
    await assertSucceeds(
      updateDoc(notice(driver()), { readAt: serverTimestamp() }),
    );
  });

  it('and cannot backdate what "read" means', async () => {
    // A client-chosen timestamp would make the read time unusable as a record.
    await assertFails(
      updateDoc(notice(driver()), { readAt: new Date('2020-01-01') }),
    );
  });

  it('the owner cannot rewrite what the notice says', async () => {
    await assertFails(
      updateDoc(notice(driver()), {
        readAt: serverTimestamp(),
        body: 'Send your ID again to 0917…',
      }),
    );
    await assertFails(updateDoc(notice(driver()), { title: 'Suspended' }));
  });

  it("nobody marks somebody else's notice read", async () => {
    await assertFails(
      updateDoc(notice(driver(RIVAL, RIVAL_UID), DRIVER_UID), {
        readAt: serverTimestamp(),
      }),
    );
  });

  it('no client writes a notice — not the owner, not an admin', async () => {
    const fresh = {
      type: NOTICE,
      title: 'Account approved',
      body: 'Your account has been approved by the admin. You can now log in.',
      createdAt: serverTimestamp(),
      readAt: null,
    };
    await assertFails(setDoc(notice(driver(), DRIVER_UID, 'forged'), fresh));
    await assertFails(setDoc(notice(admin(), DRIVER_UID, 'forged'), fresh));
  });

  it('and no client deletes one', async () => {
    await assertFails(deleteDoc(notice(driver())));
    await assertFails(deleteDoc(notice(admin(), DRIVER_UID)));
  });
});
