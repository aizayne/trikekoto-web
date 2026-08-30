// ============================================================
// TrikeKoTo — end-to-end lifecycle and concurrency tests
// ============================================================
//   npm test        (boots the emulator, runs every suite)
//
// The rules suite asserts each transition in isolation. This one drives a
// whole ride through the real client SDK — anonymous commuter, verified
// driver, actual transactions — and then attacks it with concurrent writes.
//
// Everything here goes through the deployed ruleset. The only privileged
// writes are the fixtures (driver profiles, admin docs) that an admin would
// have created beforehand.
// ============================================================

import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  GeoPoint,
  addDoc,
  collection,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-lifecycle-test';

const DRIVER = 'juan@toda.ph';
const DRIVER_UID = 'driver-uid-1';
const RIVAL = 'pedro@toda.ph';
const RIVAL_UID = 'driver-uid-2';
const COMMUTER_UID = 'commuter-uid-1';

let testEnv;

const commuter = (uid = COMMUTER_UID) =>
  testEnv.authenticatedContext(uid, { provider_id: 'anonymous' }).firestore();

const driver = (email = DRIVER, uid = DRIVER_UID) =>
  testEnv
    .authenticatedContext(uid, { email, email_verified: true })
    .firestore();

const profile = (email, uid) => ({
  email,
  uid,
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  todaChapter: 'Barangay Uno TODA',
  status: 'approved',
  ratingSum: 0,
  ratingCount: 0,
});

const snapshotOf = (email) => ({
  email,
  firstName: 'Juan',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  ratingSum: 0,
  ratingCount: 0,
});

/** The payload the Flutter client's RideWrites.create produces. */
const newRide = (overrides = {}) => ({
  commuterUid: COMMUTER_UID,
  commuterName: 'Maria',
  commuterPhone: '09181234567',
  pickup: { label: 'Plaza', geopoint: new GeoPoint(14.5995, 120.9842) },
  dropoff: { label: 'Palengke', geopoint: new GeoPoint(14.6042, 120.9887) },
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
  fareEstimate: 20,
  distanceKm: 0.62,
  rating: null,
  feedback: null,
  createdAt: serverTimestamp(),
  ...overrides,
});

/** What the commuter's greedy sweep writes when it pings a driver. */
const offerTo = (email, depth = 1) => ({
  dispatch: {
    offeredTo: email,
    offerSeq: depth,
    offerExpiresAt: null,
    attemptedDrivers: [email],
    depth,
  },
});

/**
 * The client's accept path, verbatim: read inside a transaction, refuse if
 * the pre-image moved, then claim it.
 */
async function acceptRide(db, rideId, email) {
  return runTransaction(db, async (tx) => {
    const ref = doc(db, 'rides', rideId);
    const fresh = await tx.get(ref);
    const data = fresh.data();

    if (!data) throw new Error('gone');
    if (data.status !== 'searching' || data.assignedDriver !== null) {
      throw new Error('taken');
    }

    tx.update(ref, {
      status: 'accepted',
      assignedDriver: email,
      driverSnapshot: snapshotOf(email),
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
  });
}

async function seedDrivers() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'drivers', DRIVER), profile(DRIVER, DRIVER_UID));
    await setDoc(doc(db, 'drivers', RIVAL), profile(RIVAL, RIVAL_UID));
  });
}

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
  await seedDrivers();
});

// ════════════════════════════════════════════════════════════
describe('the whole ride, start to finish', () => {
  it('books, dispatches, accepts, drives, completes, and rates', async () => {
    const rider = commuter();
    const juan = driver();

    // 1. Commuter books. Anonymous auth is what gives this document an owner.
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());
    const rideId = rideRef.id;

    // 2. The greedy sweep pings the nearest driver.
    await updateDoc(doc(rider, 'rides', rideId), offerTo(DRIVER));

    // 3. The offer is visible to that driver, and to nobody else.
    const offered = await getDoc(doc(juan, 'rides', rideId));
    assert.equal(offered.data().dispatch.offeredTo, DRIVER);
    await assertFails(
      getDoc(doc(driver(RIVAL, RIVAL_UID), 'rides', rideId)),
    );

    // 4. Accept, transactionally.
    await acceptRide(juan, rideId, DRIVER);
    let ride = (await getDoc(doc(juan, 'rides', rideId))).data();
    assert.equal(ride.status, 'accepted');
    assert.equal(ride.assignedDriver, DRIVER);
    assert.equal(ride.driverSnapshot.plateNumber, 'ABC1234');

    // 5. Driving: GPS is mirrored onto the ride so the commuter can track it
    //    without ever reading the driver index.
    await updateDoc(doc(juan, 'rides', rideId), {
      driverLocation: new GeoPoint(14.6, 120.985),
      driverLocationAt: serverTimestamp(),
    });
    await updateDoc(doc(juan, 'rides', rideId), {
      status: 'in_transit',
      startedAt: serverTimestamp(),
    });

    // 6. Complete, recording distance and fare.
    await updateDoc(doc(juan, 'rides', rideId), {
      status: 'completed',
      completedAt: serverTimestamp(),
      distanceKm: 4.2,
      fareEstimate: 25,
    });

    ride = (await getDoc(doc(rider, 'rides', rideId))).data();
    assert.equal(ride.status, 'completed');
    assert.equal(ride.fareEstimate, 25);

    // 7. The commuter rates, and the driver's aggregate moves.
    await updateDoc(doc(rider, 'rides', rideId), {
      rating: 5,
      feedback: 'Mabilis at ligtas',
      ratedAt: serverTimestamp(),
    });
    await updateDoc(doc(rider, 'drivers', DRIVER), {
      ratingSum: 5,
      ratingCount: 1,
      updatedAt: serverTimestamp(),
    });

    // withSecurityRulesDisabled resolves to void, so the value has to come
    // out through a closure rather than a return.
    let after;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      after = (await getDoc(doc(ctx.firestore(), 'drivers', DRIVER))).data();
    });
    assert.equal(after.ratingSum, 5);
    assert.equal(after.ratingCount, 1);
  });

  it('lets the commuter walk away mid-search and re-book', async () => {
    const rider = commuter();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());

    await updateDoc(doc(rider, 'rides', rideRef.id), {
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
    });

    const second = await addDoc(collection(rider, 'rides'), newRide());
    assert.notEqual(second.id, rideRef.id);
  });

  it('expires the search after ten candidates', async () => {
    const rider = commuter();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());
    const attempted = [];

    for (let depth = 1; depth <= 10; depth++) {
      attempted.push(`driver${depth}@toda.ph`);
      await updateDoc(doc(rider, 'rides', rideRef.id), {
        dispatch: {
          offeredTo: attempted[attempted.length - 1],
          offerSeq: depth,
          offerExpiresAt: null,
          attemptedDrivers: [...attempted],
          depth,
        },
      });
    }

    // The budget is spent; the sweep gives up.
    await updateDoc(doc(rider, 'rides', rideRef.id), {
      status: 'expired',
      cancelledAt: serverTimestamp(),
      cancelledBy: 'system',
      dispatch: {
        offeredTo: null,
        offerSeq: 0,
        offerExpiresAt: null,
        attemptedDrivers: [],
        depth: 0,
      },
    });

    const ride = (await getDoc(doc(rider, 'rides', rideRef.id))).data();
    assert.equal(ride.status, 'expired');
  });
});

// ════════════════════════════════════════════════════════════
// The guarantee the whole design rests on: a ride is claimed once.
describe('concurrency', () => {
  it('survives a double-tap: two simultaneous accepts, one winner', async () => {
    const rider = commuter();
    const juan = driver();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());
    await updateDoc(doc(rider, 'rides', rideRef.id), offerTo(DRIVER));

    // The same driver, firing twice before the first commit lands.
    const results = await Promise.allSettled([
      acceptRide(juan, rideRef.id, DRIVER),
      acceptRide(juan, rideRef.id, DRIVER),
    ]);

    const won = results.filter((r) => r.status === 'fulfilled');
    assert.equal(won.length, 1, 'exactly one accept may commit');

    const ride = (await getDoc(doc(juan, 'rides', rideRef.id))).data();
    assert.equal(ride.status, 'accepted');
    assert.equal(ride.assignedDriver, DRIVER);
  });

  it('refuses a driver who was never offered the ride, even mid-race', async () => {
    const rider = commuter();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());
    await updateDoc(doc(rider, 'rides', rideRef.id), offerTo(DRIVER));

    const results = await Promise.allSettled([
      acceptRide(driver(), rideRef.id, DRIVER),
      acceptRide(driver(RIVAL, RIVAL_UID), rideRef.id, RIVAL),
    ]);

    const ride = (await getDoc(doc(driver(), 'rides', rideRef.id))).data();
    assert.equal(ride.assignedDriver, DRIVER, 'the offered driver must win');

    const rivalResult = results[1];
    assert.equal(rivalResult.status, 'rejected',
      'an un-offered driver must never claim a ride');
  });

  it('resolves accept-versus-cancel without leaving a half-state', async () => {
    // A genuine production race: the commuter gives up at the same instant
    // the driver accepts. Whoever loses must not leave the ride both
    // cancelled and assigned.
    const rider = commuter();
    const juan = driver();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());
    await updateDoc(doc(rider, 'rides', rideRef.id), offerTo(DRIVER));

    await Promise.allSettled([
      acceptRide(juan, rideRef.id, DRIVER),
      updateDoc(doc(rider, 'rides', rideRef.id), {
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
    ]);

    const ride = (await getDoc(doc(rider, 'rides', rideRef.id))).data();

    // Whichever landed, the document must be internally consistent.
    if (ride.status === 'accepted') {
      assert.equal(ride.assignedDriver, DRIVER);
      assert.equal(ride.cancelledBy ?? null, null,
        'an accepted ride must not also be cancelled');
    } else {
      assert.equal(ride.status, 'cancelled');
      assert.equal(ride.assignedDriver, null,
        'a cancelled ride must not carry a driver');
    }
  });

  it('does not let a second rating slip through concurrently', async () => {
    const rider = commuter();
    const rideRef = await addDoc(collection(rider, 'rides'), newRide());

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'rides', rideRef.id), {
        status: 'completed',
        assignedDriver: DRIVER,
        driverSnapshot: snapshotOf(DRIVER),
        completedAt: new Date(),
      });
    });

    const rate = (stars) =>
      updateDoc(doc(rider, 'rides', rideRef.id), {
        rating: stars,
        ratedAt: serverTimestamp(),
      });

    const results = await Promise.allSettled([rate(5), rate(1)]);
    const accepted = results.filter((r) => r.status === 'fulfilled');
    assert.equal(accepted.length, 1, 'a ride is rated once');
  });
});
