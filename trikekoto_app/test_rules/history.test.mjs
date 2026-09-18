// ============================================================
// TrikeKoTo — ride history queries against the security rules
// ============================================================
// Each history screen lists rides with one query. These prove the rules admit
// exactly that query for its owner, and refuse the same query from anyone
// else — a history is a record of where someone went, and with whom.
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
  doc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-history-test';
const DRIVER = 'juan@toda.ph';
const DRIVER_UID = 'driver-uid-1';
const RIVAL = 'pedro@toda.ph';
const RIVAL_UID = 'driver-uid-2';
const COMMUTER_UID = 'commuter-uid-1';
const OTHER_COMMUTER_UID = 'commuter-uid-2';
const ADMIN_EMAIL = 'admin@trikekoto.ph';

let testEnv;

const commuter = (uid = COMMUTER_UID) =>
  testEnv
    .authenticatedContext(uid, { phone_number: '+639171234567', provider_id: 'phone' })
    .firestore();
const driver = (email = DRIVER, uid = DRIVER_UID) =>
  testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
const admin = () =>
  testEnv
    .authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const ride = (overrides) => ({
  commuterUid: COMMUTER_UID,
  commuterName: 'Maria',
  commuterPhone: '09181234567',
  pickup: { label: 'Plaza' },
  dropoff: { label: 'Palengke' },
  status: 'completed',
  assignedDriver: DRIVER,
  rating: null,
  createdAt: new Date(),
  ...overrides,
});

// The screens' own queries, as the app builds them.
const driverHistory = (db, email = DRIVER) => query(
  collection(db, 'rides'),
  where('assignedDriver', '==', email),
  where('status', 'in', ['completed', 'cancelled']),
  orderBy('createdAt', 'desc'),
  limit(30),
);
const commuterHistory = (db, uid = COMMUTER_UID) => query(
  collection(db, 'rides'),
  where('commuterUid', '==', uid),
  orderBy('createdAt', 'desc'),
  limit(30),
);
const allRides = (db) => query(collection(db, 'rides'), orderBy('createdAt', 'desc'), limit(30));

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'admins', ADMIN_EMAIL), { email: ADMIN_EMAIL });
    await setDoc(doc(db, 'rides', 'done'), ride({}));
    await setDoc(doc(db, 'rides', 'called-off'), ride({ status: 'cancelled', cancelledBy: 'driver' }));
    await setDoc(doc(db, 'rides', 'rivals'), ride({ assignedDriver: RIVAL, commuterUid: OTHER_COMMUTER_UID }));
  });
});

describe('ride history', () => {
  it('a driver lists their own finished rides, and only those', async () => {
    const snap = await assertSucceeds(getDocs(driverHistory(driver())));
    assert.deepEqual(snap.docs.map((d) => d.id).sort(), ['called-off', 'done']);
  });

  it("a driver cannot list another driver's history", async () => {
    await assertFails(getDocs(driverHistory(driver(RIVAL, RIVAL_UID), DRIVER)));
  });

  it('a commuter lists their own rides', async () => {
    const snap = await assertSucceeds(getDocs(commuterHistory(commuter())));
    assert.equal(snap.size, 2);
  });

  it("a commuter cannot list someone else's rides", async () => {
    await assertFails(getDocs(commuterHistory(commuter(OTHER_COMMUTER_UID), COMMUTER_UID)));
  });

  it('an admin lists every ride, and can filter by outcome', async () => {
    const all = await assertSucceeds(getDocs(allRides(admin())));
    assert.equal(all.size, 3);
    const cancelled = await assertSucceeds(getDocs(query(
      collection(admin(), 'rides'),
      where('status', '==', 'cancelled'),
      orderBy('createdAt', 'desc'),
      limit(30),
    )));
    assert.deepEqual(cancelled.docs.map((d) => d.id), ['called-off']);
  });

  it('nobody but an admin can list every ride', async () => {
    await assertFails(getDocs(allRides(commuter())));
    await assertFails(getDocs(allRides(driver())));
  });
});
