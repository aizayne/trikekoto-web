// ============================================================
// One account per mobile number — phone_claims/{number}
// ============================================================
// Firebase already gives a verified number one sign-in. What these assert is
// the rest of it: a number can be held by one account across drivers and
// commuters, a driver's typed number cannot take one already in use, and a
// booking carries the number the account proved.
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
  writeBatch,
} from 'firebase/firestore';

const PHONE = '+639171234567';
const OTHER_PHONE = '+639998887777';
const DRIVER_EMAIL = 'driver.one@toda.ph';
const OTHER_DRIVER_EMAIL = 'driver.two@toda.ph';
const ADMIN_EMAIL = 'admin@trikekoto.ph';

let testEnv;

const rider = (uid, phone = PHONE) =>
  testEnv
    .authenticatedContext(uid, { phone_number: phone, provider_id: 'phone' })
    .firestore();

const driver = (email = DRIVER_EMAIL, uid = 'driver-1') =>
  testEnv.authenticatedContext(uid, { email }).firestore();

const admin = () =>
  testEnv
    .authenticatedContext('admin-1', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const claim = (uid, role) => ({ uid, role, createdAt: serverTimestamp() });

function signUpRider(db, uid, phone = PHONE) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'riders', uid), {
    name: 'Maria',
    phone,
    profilePhotoUrl: null,
    savedAddresses: [],
    ratingSum: 0,
    ratingCount: 0,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(db, 'phone_claims', phone), claim(uid, 'rider'));
  return batch.commit();
}

function registerDriver(db, email = DRIVER_EMAIL, uid = 'driver-1', phone = PHONE) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'drivers', email), {
    email,
    uid,
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    phone,
    plateNumber: 'ABC1234',
    todaChapter: 'Uno',
    status: 'pending',
    ratingSum: 0,
    ratingCount: 0,
    createdAt: serverTimestamp(),
  });
  batch.set(doc(db, 'phone_claims', phone), claim(uid, 'driver'));
  return batch.commit();
}

const booking = (uid, commuterPhone) => ({
  commuterUid: uid,
  commuterName: 'Maria',
  commuterPhone,
  pickup: { label: 'Plaza', geopoint: new GeoPoint(14.6, 120.98) },
  dropoff: { label: 'Palengke', geopoint: new GeoPoint(14.61, 120.99) },
  notes: null,
  status: 'searching',
  dispatch: { offeredTo: null, offerSeq: 0, offerExpiresAt: null, attemptedDrivers: [], depth: 0 },
  assignedDriver: null,
  driverSnapshot: null,
  rating: null,
  createdAt: serverTimestamp(),
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'trikekoto-phone-claims-test',
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

describe('one account per number', () => {
  it('a rider can claim the number they proved', async () => {
    await assertSucceeds(signUpRider(rider('rider-1'), 'rider-1'));
  });

  it('a rider cannot claim a number they did not prove', async () => {
    await assertFails(
      setDoc(
        doc(rider('rider-1'), 'phone_claims', OTHER_PHONE),
        claim('rider-1', 'rider'),
      ),
    );
  });

  it('a second rider cannot take a claimed number', async () => {
    await signUpRider(rider('rider-1'), 'rider-1');
    await assertFails(signUpRider(rider('rider-2'), 'rider-2'));
  });

  it('a second driver cannot register with a claimed number', async () => {
    await registerDriver(driver());
    await assertFails(
      registerDriver(driver(OTHER_DRIVER_EMAIL, 'driver-2'), OTHER_DRIVER_EMAIL, 'driver-2'),
    );
  });

  it('a driver cannot register with a commuter\'s number', async () => {
    await signUpRider(rider('rider-1'), 'rider-1');
    await assertFails(registerDriver(driver()));
  });

  it('a commuter cannot sign up with a driver\'s number', async () => {
    await registerDriver(driver());
    await assertFails(signUpRider(rider('rider-1'), 'rider-1'));
  });

  it('a driver cannot claim a number that is not on their profile', async () => {
    await assertFails(
      setDoc(doc(driver(), 'phone_claims', OTHER_PHONE), claim('driver-1', 'driver')),
    );
  });

  it('a claim cannot be made in someone else\'s name', async () => {
    await assertFails(
      setDoc(doc(rider('rider-1'), 'phone_claims', PHONE), claim('rider-2', 'rider')),
    );
  });

  it('retrying a sign-up rewrites your own claim', async () => {
    const db = rider('rider-1');
    await setDoc(doc(db, 'phone_claims', PHONE), claim('rider-1', 'rider'));
    await assertSucceeds(signUpRider(db, 'rider-1'));
  });

  it('only the holder and an admin can read a claim', async () => {
    await signUpRider(rider('rider-1'), 'rider-1');
    await assertSucceeds(getDoc(doc(rider('rider-1'), 'phone_claims', PHONE)));
    await assertSucceeds(getDoc(doc(admin(), 'phone_claims', PHONE)));
    await assertFails(getDoc(doc(rider('rider-2', OTHER_PHONE), 'phone_claims', PHONE)));
  });

  it('only an admin can free a number', async () => {
    await signUpRider(rider('rider-1'), 'rider-1');
    await assertFails(deleteDoc(doc(rider('rider-1'), 'phone_claims', PHONE)));
    await assertSucceeds(deleteDoc(doc(admin(), 'phone_claims', PHONE)));
  });
});

describe('a booking carries the verified number', () => {
  beforeEach(() =>
    testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'id_verified', 'rider-1'), { role: 'rider' }),
    ),
  );

  it('accepts the number the account proved', async () => {
    await assertSucceeds(
      setDoc(doc(rider('rider-1'), 'rides', 'r1'), booking('rider-1', PHONE)),
    );
  });

  it('refuses any other number', async () => {
    await assertFails(
      setDoc(doc(rider('rider-1'), 'rides', 'r1'), booking('rider-1', OTHER_PHONE)),
    );
  });
});

describe('remembered phones', () => {
  it('no client can read or write the secret\'s hash', async () => {
    await assertFails(getDoc(doc(rider('rider-1'), 'device_logins', 'rider-1')));
    await assertFails(
      setDoc(doc(rider('rider-1'), 'device_logins', 'rider-1'), { secretHash: 'x' }),
    );
    await assertFails(getDoc(doc(admin(), 'device_logins', 'rider-1')));
  });
});
