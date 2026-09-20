// End-to-end check of driver removal, against the emulators.
//
//   cd trikekoto_app
//   npm --prefix functions run build
//   firebase emulators:exec --only functions,firestore,auth --project demo-trikekoto \
//     "node functions/test/removal.emulator.mjs"
//
// Deletes drivers/{email} the way the admin panel does — one document — and
// watches onDriverRemoved take apart everything the profile was attached to:
// the presence row, a ride under way, an offer open at that second, the
// contact details on finished rides, the ID, and the sign-in account.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { GeoPoint, getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = getFirestore();
const auth = getAuth();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail ? ` (${detail})` : ''}`);
  if (!ok) failures++;
}

const EMAIL = 'juan@toda.ph';
const RIVAL = 'pedro@toda.ph';
const at = new GeoPoint(14.9747, 120.1577);

async function waitFor(predicate, ms = 15_000) {
  const start = Date.now();
  while (Date.now() - start < ms) {
    if (await predicate()) return true;
    await sleep(250);
  }
  return false;
}

const gone = (ref) => async () => !(await ref.get()).exists;

async function seed(uid) {
  await db.doc(`drivers/${EMAIL}`).set({
    email: EMAIL, uid, firstName: 'Juan', lastName: 'Dela Cruz',
    phone: '09171234567', plateNumber: 'ABC1234',
    todaChapter: 'Barangay Uno TODA', status: 'approved', createdAt: new Date(),
  });
  await db.doc(`active_drivers/${EMAIL}`).set({
    email: EMAIL, isOnline: true, availability: 'idle',
    position: { geopoint: at, geohash: 'wdw0x' }, updatedAt: new Date(),
  });
  await db.doc(`id_submissions/${uid}`).set({
    role: 'driver', status: 'approved', idType: 'national_id',
    idPhotoPath: `ids/${uid}/card`, submittedAt: new Date(),
  });
  await db.doc(`id_verified/${uid}`).set({ role: 'driver', verifiedAt: new Date() });
  await db.doc(`notifications/${uid}/items/account_approved`).set({
    type: 'account_approved', title: 'Account approved', body: 'x',
    createdAt: new Date(), readAt: null,
  });

  const ride = (id, extra) => db.doc(`rides/${id}`).set({
    commuterUid: 'commuter-1', commuterName: 'Maria', commuterPhone: '09181234567',
    pickup: { label: 'Plaza', geopoint: at }, dropoff: { label: 'Palengke' },
    serviceType: 'regular', createdAt: new Date(),
    driverSnapshot: { email: EMAIL, firstName: 'Juan', phone: '09171234567', plateNumber: 'ABC1234' },
    ...extra,
  });
  await ride('live', { status: 'in_transit', assignedDriver: EMAIL });
  await ride('done', { status: 'completed', assignedDriver: EMAIL, rating: 5 });
  await ride('offered', {
    status: 'searching',
    dispatch: { offeredTo: EMAIL, offerSeq: 1, depth: 1, attemptedDrivers: [EMAIL],
      offerExpiresAt: new Date(Date.now() + 60_000) },
  });
  await ride('rivals', { status: 'in_transit', assignedDriver: RIVAL,
    driverSnapshot: { email: RIVAL, firstName: 'Pedro', phone: '09991112222', plateNumber: 'XYZ9999' } });
}

async function main() {
  // ── An admin removes an ordinary driver ──────────────────────────────
  const user = await auth.createUser({ email: EMAIL, password: 'test-password-1' });
  await seed(user.uid);
  await db.doc(`drivers/${EMAIL}`).delete();

  check(
    'the presence row goes, so no passenger is sent to them',
    await waitFor(gone(db.doc(`active_drivers/${EMAIL}`))),
  );
  check(
    'a ride under way is called off, so the commuter is told',
    await waitFor(async () =>
      (await db.doc('rides/live').get()).data()?.status === 'cancelled'),
    (await db.doc('rides/live').get()).data()?.cancelledBy ?? '',
  );
  check(
    'an open offer is released for the next driver',
    await waitFor(async () =>
      (await db.doc('rides/offered').get()).data()?.dispatch?.offeredTo === null),
  );

  const done = (await db.doc('rides/done').get()).data();
  check('a finished ride survives the removal', done?.status === 'completed');
  check('with the driver still named on it', done?.driverSnapshot?.firstName === 'Juan');
  check('but no phone number left on it', done?.driverSnapshot?.phone === null,
    String(done?.driverSnapshot?.phone));

  const rivals = (await db.doc('rides/rivals').get()).data();
  check("another driver's ride is untouched",
    rivals?.status === 'in_transit' && rivals?.driverSnapshot?.phone === '09991112222');

  check('the ID submission goes', await waitFor(gone(db.doc(`id_submissions/${user.uid}`))));
  check('the verification marker goes', await waitFor(gone(db.doc(`id_verified/${user.uid}`))));
  check('their notices go',
    await waitFor(gone(db.doc(`notifications/${user.uid}/items/account_approved`))));
  check(
    'and the sign-in account goes, so they cannot register again',
    await waitFor(async () => {
      try { await auth.getUser(user.uid); return false; } catch { return true; }
    }),
  );

  // ── The same address is also an admin ────────────────────────────────
  const officer = await auth.createUser({ email: RIVAL, password: 'test-password-2' });
  await db.doc(`admins/${RIVAL}`).set({ email: RIVAL });
  await db.doc(`drivers/${RIVAL}`).set({
    email: RIVAL, uid: officer.uid, firstName: 'Pedro', lastName: 'Cruz',
    phone: '09991112222', plateNumber: 'XYZ9999',
    todaChapter: 'Barangay Uno TODA', status: 'approved', createdAt: new Date(),
  });
  await db.doc(`drivers/${RIVAL}`).delete();
  await sleep(5000);

  let officerStillThere = true;
  try { await auth.getUser(officer.uid); } catch { officerStillThere = false; }
  check(
    'an admin who is also a driver keeps their login',
    officerStillThere,
    'the chapter would have been locked out of its own panel',
  );

  console.log(failures === 0 ? '\nALL PASS' : `\n${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
