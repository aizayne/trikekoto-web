// ============================================================
// TrikeKoTo — Firestore security rules tests
// ============================================================
//   npm install
//   npm test          (boots the emulator, runs the suite, tears down)
//
// These cover the cases where a mistake is silent and expensive: the
// double-booking race, self-approval, cross-commuter reads, rating
// forgery, and the unverified-email admin escalation.
// ============================================================

import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  GeoPoint,
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-rules-test';

const DRIVER_EMAIL = 'driver.one@toda.ph';
const DRIVER_UID = 'driver-uid-1';
const OTHER_DRIVER_EMAIL = 'driver.two@toda.ph';
const OTHER_DRIVER_UID = 'driver-uid-2';
const ADMIN_EMAIL = 'admin@trikekoto.ph';
const ADMIN_UID = 'admin-uid-1';
const COMMUTER_UID = 'commuter-uid-1';
const OTHER_COMMUTER_UID = 'commuter-uid-2';

let testEnv;

// ── Contexts ────────────────────────────────────────────────

/** A commuter: anonymous auth, so a uid and no email claim at all. */
/** A commuter: phone-verified, which every commuter now is. */
const commuter = (uid = COMMUTER_UID, phone = '+639171234567') =>
  testEnv
    .authenticatedContext(uid, { phone_number: phone, provider_id: 'phone' })
    .firestore();

/** A leftover anonymous session, from before accounts were required. */
const anonCommuter = (uid = COMMUTER_UID) =>
  testEnv.authenticatedContext(uid, { provider_id: 'anonymous' }).firestore();

const driver = (email = DRIVER_EMAIL, uid = DRIVER_UID, verified = true) =>
  testEnv
    .authenticatedContext(uid, { email, email_verified: verified })
    .firestore();

const admin = (verified = true) =>
  testEnv
    .authenticatedContext(ADMIN_UID, { email: ADMIN_EMAIL, email_verified: verified })
    .firestore();

const anon = () => testEnv.unauthenticatedContext().firestore();

// ── Fixtures ────────────────────────────────────────────────

const driverProfile = (email, status = 'approved') => ({
  email,
  uid: email === DRIVER_EMAIL ? DRIVER_UID : OTHER_DRIVER_UID,
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  todaChapter: 'Barangay Uno TODA',
  status,
  ratingSum: 0,
  ratingCount: 0,
});

const snapshotFor = (email) => ({
  email,
  firstName: 'Juan',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  ratingSum: 0,
  ratingCount: 0,
});

const rideDoc = (overrides = {}) => ({
  commuterUid: COMMUTER_UID,
  commuterName: 'Maria',
  commuterPhone: '09181234567',
  commuterPhotoUrl: null,
  pickup: { label: 'Plaza', geopoint: new GeoPoint(14.5995, 120.9842) },
  dropoff: { label: 'Palengke', geopoint: new GeoPoint(14.6, 120.99) },
  notes: null,
  status: 'searching',
  dispatch: {
    offeredTo: null,
    offerSeq: 0,
    offerExpiresAt: null,
    attemptedDrivers: [],
    depth: 0,
  },
  assignedDriver: null,
  driverSnapshot: null,
  driverLocation: null,
  driverLocationAt: null,
  scheduledFor: null,
  rating: null,
  feedback: null,
  createdAt: new Date(),
  ...overrides,
});

/** A ride created straight through the admin backdoor, bypassing rules. */
async function seedRide(id, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rides', id), rideDoc(overrides));
  });
}

async function seedDriver(email, status = 'approved') {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'drivers', email), driverProfile(email, status));
  });
}

async function seedAdmin(email = ADMIN_EMAIL) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'admins', email), {
      email,
      displayName: 'Ops',
      createdAt: new Date(),
    });
  });
}

// ── Lifecycle ───────────────────────────────────────────────

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ════════════════════════════════════════════════════════════
describe('rides — creation and ownership', () => {
  it('lets a signed-in commuter create a searching ride', async () => {
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r1'), {
        ...rideDoc(),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('rejects an unauthenticated ride request', async () => {
    await assertFails(
      setDoc(doc(anon(), 'rides', 'r1'), {
        ...rideDoc(),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a ride created in someone else\'s name', async () => {
    await assertFails(
      setDoc(doc(commuter(OTHER_COMMUTER_UID), 'rides', 'r1'), {
        ...rideDoc({ commuterUid: COMMUTER_UID }),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a ride that starts out already assigned', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'rides', 'r1'), {
        ...rideDoc({ status: 'accepted', assignedDriver: DRIVER_EMAIL }),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a ride that starts out rated', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'rides', 'r1'), {
        ...rideDoc({ rating: 5 }),
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('hides a commuter\'s ride — with their phone number — from other commuters', async () => {
    await seedRide('r1');
    await assertSucceeds(getDoc(doc(commuter(), 'rides', 'r1')));
    await assertFails(getDoc(doc(commuter(OTHER_COMMUTER_UID), 'rides', 'r1')));
    await assertFails(getDoc(doc(anon(), 'rides', 'r1')));
  });

  it('hides a searching ride from a driver who has not been offered it', async () => {
    await seedRide('r1');
    await assertFails(getDoc(doc(driver(), 'rides', 'r1')));
  });

  it('shows the ride to the driver currently being offered it', async () => {
    await seedRide('r1', {
      dispatch: {
        offeredTo: DRIVER_EMAIL,
        offerSeq: 1,
        offerExpiresAt: null,
        attemptedDrivers: [DRIVER_EMAIL],
        depth: 1,
      },
    });
    await assertSucceeds(getDoc(doc(driver(), 'rides', 'r1')));
  });
});

// ════════════════════════════════════════════════════════════
describe('rides — dispatch', () => {
  const offered = (email) => ({
    dispatch: {
      offeredTo: email,
      offerSeq: 1,
      offerExpiresAt: null,
      attemptedDrivers: [email],
      depth: 1,
    },
  });

  it('lets the commuter widen the search', async () => {
    await seedRide('r1');
    await assertSucceeds(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        dispatch: {
          offeredTo: DRIVER_EMAIL,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [DRIVER_EMAIL],
          depth: 1,
        },
      }),
    );
  });

  it('refuses to let the search walk backwards', async () => {
    await seedRide('r1', {
      dispatch: {
        offeredTo: null,
        offerSeq: 3,
        offerExpiresAt: null,
        attemptedDrivers: [DRIVER_EMAIL],
        depth: 3,
      },
    });
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        dispatch: {
          offeredTo: DRIVER_EMAIL,
          offerSeq: 4,
          offerExpiresAt: null,
          attemptedDrivers: [DRIVER_EMAIL],
          depth: 1,
        },
      }),
    );
  });

  it('caps the search at 10 candidates', async () => {
    await seedRide('r1');
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        dispatch: {
          offeredTo: DRIVER_EMAIL,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [DRIVER_EMAIL],
          depth: 11,
        },
      }),
    );
  });

  it('stops a commuter from smuggling a status change into a dispatch write', async () => {
    await seedRide('r1');
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        status: 'completed',
        dispatch: {
          offeredTo: DRIVER_EMAIL,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [DRIVER_EMAIL],
          depth: 1,
        },
      }),
    );
  });

  it('lets the offered driver decline', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', offered(DRIVER_EMAIL));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        dispatch: {
          offeredTo: null,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [DRIVER_EMAIL],
          depth: 1,
        },
      }),
    );
  });

  it('stops a declining driver from erasing the attempted list', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', offered(DRIVER_EMAIL));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        dispatch: {
          offeredTo: null,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [],
          depth: 1,
        },
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('rides — acceptance (the double-booking guard)', () => {
  const offeredTo = (email) => ({
    dispatch: {
      offeredTo: email,
      offerSeq: 1,
      offerExpiresAt: null,
      attemptedDrivers: [email],
      depth: 1,
    },
  });

  const acceptPayload = (email) => ({
    status: 'accepted',
    assignedDriver: email,
    driverSnapshot: snapshotFor(email),
    driverLocation: new GeoPoint(14.5995, 120.9842),
    driverLocationAt: serverTimestamp(),
    acceptedAt: serverTimestamp(),
    dispatch: {
      offeredTo: null,
      offerSeq: 0,
      offerExpiresAt: null,
      attemptedDrivers: [],
      depth: 0,
    },
  });

  it('lets the offered, approved driver accept', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), acceptPayload(DRIVER_EMAIL)),
    );
  });

  it('blocks a driver who was never offered the ride', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await seedDriver(OTHER_DRIVER_EMAIL, 'approved');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertFails(
      updateDoc(
        doc(driver(OTHER_DRIVER_EMAIL, OTHER_DRIVER_UID), 'rides', 'r1'),
        acceptPayload(OTHER_DRIVER_EMAIL),
      ),
    );
  });

  it('blocks a suspended driver', async () => {
    await seedDriver(DRIVER_EMAIL, 'suspended');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), acceptPayload(DRIVER_EMAIL)),
    );
  });

  it('blocks a driver still pending verification', async () => {
    await seedDriver(DRIVER_EMAIL, 'pending');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), acceptPayload(DRIVER_EMAIL)),
    );
  });

  it('cannot steal a ride that is already accepted, even without a transaction', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await seedDriver(OTHER_DRIVER_EMAIL, 'approved');
    // Already taken by driver two, but still offered to driver one — the
    // exact interleaving a lost race produces.
    await seedRide('r1', {
      ...offeredTo(DRIVER_EMAIL),
      status: 'accepted',
      assignedDriver: OTHER_DRIVER_EMAIL,
      driverSnapshot: snapshotFor(OTHER_DRIVER_EMAIL),
    });
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), acceptPayload(DRIVER_EMAIL)),
    );
  });

  it('cannot assign the ride to a different driver', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        ...acceptPayload(DRIVER_EMAIL),
        assignedDriver: OTHER_DRIVER_EMAIL,
      }),
    );
  });

  it('cannot advertise a plate number that is not on the profile', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await seedRide('r1', offeredTo(DRIVER_EMAIL));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        ...acceptPayload(DRIVER_EMAIL),
        driverSnapshot: { ...snapshotFor(DRIVER_EMAIL), plateNumber: 'FAKE999' },
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('rides — lifecycle and tracking', () => {
  const assigned = (status = 'accepted') => ({
    status,
    assignedDriver: DRIVER_EMAIL,
    driverSnapshot: snapshotFor(DRIVER_EMAIL),
  });

  it('walks accepted → in_transit → completed', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('accepted'));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'in_transit',
        startedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('records distance and fare on completion', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('in_transit'));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('completes with nothing but the transition', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('in_transit'));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses a completion that smuggles in a fare field', async () => {
    // The app no longer quotes or stores fares. The rules must refuse the
    // field outright rather than merely validate it, or a modified client
    // could reintroduce a number nobody agreed to.
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('in_transit'));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'completed',
        completedAt: serverTimestamp(),
        fareEstimate: 50,
      }),
    );
  });

  it('stops the commuter from rewriting the fare they were charged', async () => {
    await seedRide('r1', {
      ...assigned('completed'),
      fareEstimate: 25,
      distanceKm: 4.2,
    });
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), { fareEstimate: 1 }),
    );
    // ...not even alongside a legitimate rating.
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 5,
        ratedAt: serverTimestamp(),
        fareEstimate: 1,
      }),
    );
  });

  it('refuses to skip straight from accepted to completed', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('accepted'));
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('lets the assigned driver stream GPS onto the ride', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r1', assigned('in_transit'));
    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r1'), {
        driverLocation: new GeoPoint(14.6, 120.99),
        driverLocationAt: serverTimestamp(),
      }),
    );
  });

  it('refuses GPS writes from a driver who is not on the ride', async () => {
    await seedDriver(OTHER_DRIVER_EMAIL);
    await seedRide('r1', assigned('in_transit'));
    await assertFails(
      updateDoc(
        doc(driver(OTHER_DRIVER_EMAIL, OTHER_DRIVER_UID), 'rides', 'r1'),
        {
          driverLocation: new GeoPoint(14.6, 120.99),
          driverLocationAt: serverTimestamp(),
        },
      ),
    );
  });

  it('lets the commuter cancel while searching', async () => {
    await seedRide('r1');
    await assertSucceeds(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        status: 'cancelled',
        cancelledAt: serverTimestamp(),
        cancelledBy: 'commuter',
        dispatch: {
          offeredTo: null,
          offerSeq: 0,
          offerExpiresAt: null,
          attemptedDrivers: [],
          depth: 0,
        },
      }),
    );
  });

  it('refuses to let a stranger cancel someone else\'s ride', async () => {
    await seedRide('r1');
    await assertFails(
      updateDoc(doc(commuter(OTHER_COMMUTER_UID), 'rides', 'r1'), {
        status: 'cancelled',
        cancelledAt: serverTimestamp(),
        cancelledBy: 'commuter',
      }),
    );
  });

  it('never deletes rides — they are the analytics trail', async () => {
    await seedRide('r1');
    await assertFails(deleteDoc(doc(commuter(), 'rides', 'r1')));
    await seedAdmin();
    await assertFails(deleteDoc(doc(admin(), 'rides', 'r1')));
  });
});

// ════════════════════════════════════════════════════════════
describe('ratings', () => {
  const completed = () => ({
    status: 'completed',
    assignedDriver: DRIVER_EMAIL,
    driverSnapshot: snapshotFor(DRIVER_EMAIL),
    completedAt: new Date(),
  });

  it('accepts one rating from the commuter who took the ride', async () => {
    await seedRide('r1', completed());
    await assertSucceeds(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 5,
        feedback: 'Mabilis at ligtas',
        ratedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a second rating', async () => {
    await seedRide('r1', { ...completed(), rating: 4, ratedAt: new Date() });
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 1,
        ratedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects out-of-range stars', async () => {
    await seedRide('r1', completed());
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 99,
        ratedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects a rating on a ride that never completed', async () => {
    await seedRide('r1', { status: 'in_transit', assignedDriver: DRIVER_EMAIL });
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 5,
        ratedAt: serverTimestamp(),
      }),
    );
  });

  // ── The aggregate is server-only (step 68) ────────────────
  //
  // These three used to assert that a commuter could post a correctly-
  // sized increment themselves. `onRideRated` now owns the aggregate and
  // writes through the Admin SDK, which is not subject to these rules —
  // so every client write of these fields is refused, well-formed or not.
  //
  // Leaving the old permission in place alongside the deployed function
  // would have counted every rating twice: the function's `ratingCounted`
  // guard stops it re-running, but it cannot see a client's increment.

  it('refuses a commuter increment even when the arithmetic is correct', async () => {
    // The exact write the pre-cutover rules allowed. This is the assertion
    // that would break if the clause were ever restored.
    await seedDriver(DRIVER_EMAIL);
    await assertFails(
      updateDoc(doc(commuter(), 'drivers', DRIVER_EMAIL), {
        ratingSum: 5,
        ratingCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses an inflated increment', async () => {
    await seedDriver(DRIVER_EMAIL);
    await assertFails(
      updateDoc(doc(commuter(), 'drivers', DRIVER_EMAIL), {
        ratingSum: 500,
        ratingCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('refuses an increment bundled with a status change', async () => {
    // Seeded as pending so the status write is a real change rather than a
    // no-op that diff().affectedKeys() would not report.
    await seedDriver(DRIVER_EMAIL, 'pending');
    await assertFails(
      updateDoc(doc(commuter(), 'drivers', DRIVER_EMAIL), {
        ratingSum: 5,
        ratingCount: 1,
        status: 'approved',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('still records the rating on the ride, which is what the function reads', async () => {
    // The cutover must not have broken the commuter's half. The function
    // derives its increment from `rides/{id}.rating`, so if this write were
    // refused no rating would be counted at all.
    await seedRide('r1', completed());
    await assertSucceeds(
      updateDoc(doc(commuter(), 'rides', 'r1'), {
        rating: 4,
        ratedAt: serverTimestamp(),
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('drivers — registration and verification', () => {
  const registration = (email) => ({
    email,
    uid: DRIVER_UID,
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    phone: '09171234567',
    plateNumber: 'ABC1234',
    todaChapter: 'Barangay Uno TODA',
    status: 'pending',
    ratingSum: 0,
    ratingCount: 0,
    createdAt: serverTimestamp(),
  });

  it('registers a driver as pending', async () => {
    await assertSucceeds(
      setDoc(doc(driver(), 'drivers', DRIVER_EMAIL), registration(DRIVER_EMAIL)),
    );
  });

  it('refuses a driver who tries to register as already approved', async () => {
    await assertFails(
      setDoc(doc(driver(), 'drivers', DRIVER_EMAIL), {
        ...registration(DRIVER_EMAIL),
        status: 'approved',
      }),
    );
  });

  it('refuses registration under another driver\'s email', async () => {
    await assertFails(
      setDoc(
        doc(driver(), 'drivers', OTHER_DRIVER_EMAIL),
        registration(OTHER_DRIVER_EMAIL),
      ),
    );
  });

  it('matches emails case-insensitively', async () => {
    await assertSucceeds(
      setDoc(
        doc(
          driver('Driver.One@TODA.ph', DRIVER_UID),
          'drivers',
          DRIVER_EMAIL,
        ),
        registration(DRIVER_EMAIL),
      ),
    );
  });

  it('lets a driver edit their own contact details', async () => {
    await seedDriver(DRIVER_EMAIL, 'approved');
    await assertSucceeds(
      updateDoc(doc(driver(), 'drivers', DRIVER_EMAIL), {
        phone: '09990000000',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('stops a driver from approving themselves', async () => {
    await seedDriver(DRIVER_EMAIL, 'pending');
    await assertFails(
      updateDoc(doc(driver(), 'drivers', DRIVER_EMAIL), { status: 'approved' }),
    );
  });

  it('stops a suspended driver from un-suspending themselves', async () => {
    await seedDriver(DRIVER_EMAIL, 'suspended');
    await assertFails(
      updateDoc(doc(driver(), 'drivers', DRIVER_EMAIL), { status: 'approved' }),
    );
  });

  it('keeps driver phone numbers away from commuters', async () => {
    await seedDriver(DRIVER_EMAIL);
    await assertFails(getDoc(doc(commuter(), 'drivers', DRIVER_EMAIL)));
    await assertSucceeds(getDoc(doc(driver(), 'drivers', DRIVER_EMAIL)));
  });
});

// ════════════════════════════════════════════════════════════
describe('admins', () => {
  it('lets a verified admin approve a driver', async () => {
    await seedAdmin();
    await seedDriver(DRIVER_EMAIL, 'pending');
    await assertSucceeds(
      updateDoc(doc(admin(), 'drivers', DRIVER_EMAIL), {
        status: 'approved',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('rejects an admin whose email address was never verified', async () => {
    // The escalation this guards: anyone can register an email/password
    // account for an address they do not own. Without email_verified, that
    // token would satisfy an email-keyed admin check.
    await seedAdmin();
    await seedDriver(DRIVER_EMAIL, 'pending');
    await assertFails(
      updateDoc(doc(admin(false), 'drivers', DRIVER_EMAIL), {
        status: 'approved',
      }),
    );
  });

  it('does not let anyone mint an admin from a client', async () => {
    await seedAdmin();
    await assertFails(
      setDoc(doc(admin(), 'admins', DRIVER_EMAIL), { email: DRIVER_EMAIL }),
    );
    await assertFails(
      setDoc(doc(driver(), 'admins', DRIVER_EMAIL), { email: DRIVER_EMAIL }),
    );
  });

  it('lets a user check their own admin status without an error', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(driver(), 'admins', DRIVER_EMAIL)),
    );
    assert.equal(snap.exists(), false);
  });

  it('lets an admin read every ride', async () => {
    await seedAdmin();
    await seedRide('r1');
    await assertSucceeds(getDoc(doc(admin(), 'rides', 'r1')));
  });

  // isAdmin() is the LAST clause of the rides update rule, so it is the one
  // at risk if the chain exhausts Firestore's 1000-expression budget before
  // reaching it — the rule would return deny and an admin override would
  // fail in production for a reason no error message explains.
  it('lets an admin force-cancel a ride despite being the last clause', async () => {
    await seedAdmin();
    await seedRide('r1', {
      status: 'accepted',
      assignedDriver: DRIVER_EMAIL,
      driverSnapshot: snapshotFor(DRIVER_EMAIL),
    });
    await assertSucceeds(
      updateDoc(doc(admin(), 'rides', 'r1'), {
        status: 'cancelled',
        cancelledAt: serverTimestamp(),
        cancelledBy: 'system',
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('active_drivers', () => {
  const presence = (email) => ({
    email,
    isOnline: true,
    availability: 'idle',
    position: { geohash: 'wdw2q1', geopoint: new GeoPoint(14.5995, 120.9842) },
    updatedAt: serverTimestamp(),
  });

  it('lets a driver publish their own presence', async () => {
    await assertSucceeds(
      setDoc(doc(driver(), 'active_drivers', DRIVER_EMAIL), presence(DRIVER_EMAIL)),
    );
  });

  it('stops a driver from writing to another driver\'s presence doc', async () => {
    await assertFails(
      setDoc(
        doc(driver(), 'active_drivers', OTHER_DRIVER_EMAIL),
        presence(OTHER_DRIVER_EMAIL),
      ),
    );
  });

  it('refuses a backdated ping', async () => {
    await assertFails(
      setDoc(doc(driver(), 'active_drivers', DRIVER_EMAIL), {
        ...presence(DRIVER_EMAIL),
        updatedAt: new Date(2020, 0, 1),
      }),
    );
  });

  it('lets a commuter run the nearest-driver search', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'active_drivers', DRIVER_EMAIL), {
        ...presence(DRIVER_EMAIL),
        updatedAt: new Date(),
      });
    });
    await assertSucceeds(getDoc(doc(commuter(), 'active_drivers', DRIVER_EMAIL)));
  });

  it('keeps the dispatch index closed to the unauthenticated', async () => {
    await assertFails(getDoc(doc(anon(), 'active_drivers', DRIVER_EMAIL)));
  });
});

// ════════════════════════════════════════════════════════════
describe('feedback and config', () => {
  const report = (uid = COMMUTER_UID) => ({
    submittedByUid: uid,
    category: 'issue',
    role: 'commuter',
    message: 'Ang mahal ng singil.',
    contact: null,
    resolved: false,
    createdAt: serverTimestamp(),
  });

  it('accepts a report from a signed-in commuter', async () => {
    await assertSucceeds(setDoc(doc(commuter(), 'feedback', 'f1'), report()));
  });

  it('rejects a report filed under someone else\'s uid', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'feedback', 'f1'), report(OTHER_COMMUTER_UID)),
    );
  });

  it('rejects a report that arrives pre-resolved', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'feedback', 'f1'), { ...report(), resolved: true }),
    );
  });

  it('rejects an unknown category', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'feedback', 'f1'), { ...report(), category: 'spam' }),
    );
  });

  it('keeps reports private from other users but visible to admins', async () => {
    await assertSucceeds(setDoc(doc(commuter(), 'feedback', 'f1'), report()));
    await assertFails(getDoc(doc(commuter(OTHER_COMMUTER_UID), 'feedback', 'f1')));
    await seedAdmin();
    await assertSucceeds(getDoc(doc(admin(), 'feedback', 'f1')));
  });

  it('lets anyone signed in read config, but only admins write it', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config', 'app'), {
        searchRadiusKm: 5,
        offerTimeoutSeconds: 15,
        maxDriversToTry: 10,
      });
    });
    await assertSucceeds(getDoc(doc(commuter(), 'config', 'app')));
    await assertFails(
      updateDoc(doc(commuter(), 'config', 'app'), { searchRadiusKm: 500 }),
    );
    await seedAdmin();
    await assertSucceeds(
      updateDoc(doc(admin(), 'config', 'app'), { searchRadiusKm: 7 }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('default deny', () => {
  it('refuses collections the rules never mention', async () => {
    await seedAdmin();
    await assertFails(setDoc(doc(commuter(), 'anything_else', 'x'), { a: 1 }));
    await assertFails(setDoc(doc(admin(), 'anything_else', 'x'), { a: 1 }));
  });
});

// ════════════════════════════════════════════════════════════
// The admin analytics panel runs one query shape. A rules change that
// broke it would leave the panel permanently empty in production while
// every other test still passed, so the exact query is asserted here.
describe('admin analytics query', () => {
  const analyticsQuery = (db) =>
    query(
      collection(db, 'rides'),
      where('createdAt', '>=', new Date(Date.now() - 7 * 864e5)),
      orderBy('createdAt', 'desc'),
      limit(2000),
    );

  it('an admin can read the analytics window', async () => {
    await seedAdmin();
    await seedRide('ride-a', { status: 'completed', fareEstimate: 40 });
    await seedRide('ride-b', { status: 'cancelled' });

    const snap = await assertSucceeds(getDocs(analyticsQuery(admin())));
    assert.equal(snap.size, 2);
  });

  it('an unverified admin cannot', async () => {
    await seedAdmin();
    await seedRide('ride-a');
    // isAdmin() requires email_verified; an email-keyed check alone would
    // hand the whole ride history to anyone who typed the address.
    await assertFails(getDocs(analyticsQuery(admin(false))));
  });

  it('a driver cannot read every ride by asking for a date range', async () => {
    await seedAdmin();
    await seedDriver(DRIVER_EMAIL);
    await seedRide('ride-a');
    // Rides carry commuter names and phone numbers.
    await assertFails(getDocs(analyticsQuery(driver())));
  });

  it('a commuter cannot either', async () => {
    await seedRide('ride-a');
    await assertFails(getDocs(analyticsQuery(commuter())));
  });

  it('and neither can a signed-out client', async () => {
    await seedRide('ride-a');
    await assertFails(getDocs(analyticsQuery(anon())));
  });
});
// ════════════════════════════════════════════════════════════
// The rider's photo travels on the ride so the driver can recognise them —
// a driver cannot read riders/{uid}, and should not be able to.
describe('commuter photo on a ride', () => {
  it('a ride may carry a photo URL', async () => {
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r-photo'), rideDoc({
        createdAt: serverTimestamp(),
        commuterPhotoUrl: 'https://firebasestorage.example/riders/u/profile',
      })),
    );
  });

  it('a ride without one is still valid — most commuters are anonymous',
    async () => {
      // Rules treat a *missing* field as an error rather than null, so an
      // absent photo must be tolerated explicitly or every anonymous
      // booking is refused.
      const d = rideDoc({ createdAt: serverTimestamp() });
      delete d.commuterPhotoUrl;
      await assertSucceeds(setDoc(doc(commuter(), 'rides', 'r-nophoto'), d));
    });

  it('rejects an over-long value in the photo field', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'rides', 'r-bad'), rideDoc({
        createdAt: serverTimestamp(),
        commuterPhotoUrl: 'x'.repeat(501),
      })),
    );
  });

  it('rejects a non-string in the photo field', async () => {
    await assertFails(
      setDoc(doc(commuter(), 'rides', 'r-bad2'),
        rideDoc({ createdAt: serverTimestamp(), commuterPhotoUrl: 42 })),
    );
  });

  it('the assigned driver can read it', async () => {
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r-assigned', {
      status: 'accepted',
      assignedDriver: DRIVER_EMAIL,
      driverSnapshot: snapshotFor(DRIVER_EMAIL),
      commuterPhotoUrl: 'https://firebasestorage.example/riders/u/profile',
    });
    const snap = await assertSucceeds(
      getDoc(doc(driver(), 'rides', 'r-assigned')),
    );
    assert.ok(snap.data().commuterPhotoUrl);
  });

  it('an unrelated driver still cannot', async () => {
    await seedDriver(OTHER_DRIVER_EMAIL);
    await seedRide('r-assigned', {
      status: 'accepted',
      assignedDriver: DRIVER_EMAIL,
      commuterPhotoUrl: 'https://firebasestorage.example/riders/u/profile',
    });
    await assertFails(
      getDoc(doc(driver(OTHER_DRIVER_EMAIL, OTHER_DRIVER_UID),
        'rides', 'r-assigned')),
    );
  });
});
// ════════════════════════════════════════════════════════════
// Accounts are required. The client screens can be bypassed; this is the
// control that actually holds, and it holds whether or not anonymous
// sign-in is still enabled in the Firebase console.
describe('booking requires a verified phone', () => {
  it('a phone-verified commuter can book', async () => {
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r-ok'),
        rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('an anonymous session cannot', async () => {
    // A leftover session from before the change, or a modified client
    // calling signInAnonymously against a provider left enabled.
    await assertFails(
      setDoc(doc(anonCommuter(), 'rides', 'r-anon'),
        rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('an unauthenticated client cannot', async () => {
    await assertFails(
      setDoc(doc(anon(), 'rides', 'r-none'),
        rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('a driver signed in by email cannot book as a commuter', async () => {
    // No phone_number claim, so the same gate refuses them.
    await assertFails(
      setDoc(doc(driver(), 'rides', 'r-driver'),
        rideDoc({ createdAt: serverTimestamp() })),
    );
  });
});





// ════════════════════════════════════════════════════════════
// The pilot stop button. This is the only rollback available once the APK is
// on drivers' phones, so it is asserted rather than trusted.
describe('acceptingRides kill switch', () => {
  async function setConfig(fields) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config', 'app'), fields);
    });
  }

  it('bookings work when the flag is absent', async () => {
    await setConfig({ searchRadiusKm: 5 });
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r-open'), rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('bookings work with no config document at all', async () => {
    // A project that has not been seeded must still work — failing closed
    // would make a missing document look like a broken ruleset.
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r-noconfig'), rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('bookings work when the flag is explicitly true', async () => {
    await setConfig({ acceptingRides: true });
    await assertSucceeds(
      setDoc(doc(commuter(), 'rides', 'r-true'), rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('flipping it to false halts new bookings', async () => {
    await setConfig({ acceptingRides: false });
    await assertFails(
      setDoc(doc(commuter(), 'rides', 'r-stopped'), rideDoc({ createdAt: serverTimestamp() })),
    );
  });

  it('a ride already in flight still completes while stopped', async () => {
    // Pressing stop must never strand a passenger sitting in a tricycle.
    await seedAdmin();
    await seedDriver(DRIVER_EMAIL);
    await seedRide('r-inflight', {
      status: 'in_transit',
      assignedDriver: DRIVER_EMAIL,
      driverSnapshot: snapshotFor(DRIVER_EMAIL),
    });
    await setConfig({ acceptingRides: false });

    await assertSucceeds(
      updateDoc(doc(driver(), 'rides', 'r-inflight'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('only an admin can flip it', async () => {
    await seedAdmin();
    await setConfig({ acceptingRides: true });
    await assertFails(
      updateDoc(doc(commuter(), 'config', 'app'), { acceptingRides: false }),
    );
    await assertSucceeds(
      updateDoc(doc(admin(), 'config', 'app'), { acceptingRides: false }),
    );
  });
});
