// ============================================================
// TrikeKoTo — adversarial rules tests
// ============================================================
// Written from the attacker's side rather than the feature's. Each test asks
// "what could someone with a modified client actually do?" and pins the
// answer, so a future rules change that widens access fails here first.
//
// Three tests near the bottom assert that a KNOWN GAP still behaves as
// documented. They are not endorsements — they are tripwires. If someone
// closes one of those gaps, the test fails and the security review gets
// updated along with it.
// ============================================================

import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  GeoPoint,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-attack-test';

const VICTIM = 'victim@toda.ph';
const ATTACKER = 'attacker@toda.ph';
const ATTACKER_UID = 'attacker-uid';
const COMMUTER_UID = 'commuter-uid-1';
const OTHER_COMMUTER = 'commuter-uid-2';

let testEnv;

const anon = () => testEnv.unauthenticatedContext().firestore();
/** A commuter: phone-verified, which every commuter now is. */
const commuter = (uid = COMMUTER_UID, phone = '+639171234567') =>
  testEnv
    .authenticatedContext(uid, { phone_number: phone, provider_id: 'phone' })
    .firestore();

/** A leftover anonymous session, from before accounts were required. */
const anonCommuter = (uid = COMMUTER_UID) =>
  testEnv.authenticatedContext(uid, { provider_id: 'anonymous' }).firestore();
const driver = (email = ATTACKER, uid = ATTACKER_UID, verified = true) =>
  testEnv
    .authenticatedContext(uid, { email, email_verified: verified })
    .firestore();

const profileOf = (email, status = 'approved') => ({
  email,
  uid: 'uid-' + email,
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  todaChapter: 'Barangay Uno TODA',
  status,
  ratingSum: 0,
  ratingCount: 0,
});

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'drivers', VICTIM), profileOf(VICTIM));
    await setDoc(doc(db, 'drivers', ATTACKER), profileOf(ATTACKER));
    await setDoc(doc(db, 'rides', 'victim-ride'), {
      commuterUid: COMMUTER_UID,
      commuterName: 'Maria',
      commuterPhone: '09181234567',
      pickup: { label: 'Plaza', geopoint: new GeoPoint(14.5995, 120.9842) },
      dropoff: { label: 'Palengke', geopoint: new GeoPoint(14.6, 120.99) },
      status: 'searching',
      dispatch: {
        offeredTo: VICTIM,
        offerSeq: 1,
        offerExpiresAt: null,
        attemptedDrivers: [VICTIM],
        depth: 1,
      },
      assignedDriver: null,
      rating: null,
      createdAt: new Date(),
    });
  });
});

// ════════════════════════════════════════════════════════════
describe('harvesting personal data', () => {
  it('a commuter cannot read the driver roster', async () => {
    // Driver documents hold phone numbers and licence details.
    await assertFails(getDoc(doc(commuter(), 'drivers', VICTIM)));
    await assertFails(getDocs(collection(commuter(), 'drivers')));
  });

  it('a driver cannot read another driver', async () => {
    await assertFails(getDoc(doc(driver(), 'drivers', VICTIM)));
  });

  it('nobody unauthenticated can read anything', async () => {
    for (const path of [
      ['drivers', VICTIM],
      ['rides', 'victim-ride'],
      ['active_drivers', VICTIM],
      ['admins', VICTIM],
    ]) {
      await assertFails(getDoc(doc(anon(), ...path)));
    }
  });

  it('a commuter cannot enumerate other commuters’ rides', async () => {
    // The ride holds a name, a phone number, and a home pickup point.
    await assertFails(getDocs(collection(commuter(OTHER_COMMUTER), 'rides')));
    await assertFails(
      getDoc(doc(commuter(OTHER_COMMUTER), 'rides', 'victim-ride')),
    );
  });

  it('a driver cannot trawl rides they were not offered', async () => {
    await assertFails(getDoc(doc(driver(), 'rides', 'victim-ride')));
    await assertFails(
      getDocs(query(collection(driver(), 'rides'),
        where('status', '==', 'searching'))),
    );
  });

  it('a commuter cannot read another commuter’s feedback', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'feedback', 'f1'), {
        submittedByUid: COMMUTER_UID,
        category: 'issue',
        role: 'commuter',
        message: 'private complaint',
        resolved: false,
        createdAt: new Date(),
      });
    });
    await assertFails(getDoc(doc(commuter(OTHER_COMMUTER), 'feedback', 'f1')));
    await assertFails(getDocs(collection(commuter(), 'feedback')));
  });
});

// ════════════════════════════════════════════════════════════
describe('privilege escalation', () => {
  it('a driver cannot promote themselves to admin', async () => {
    await assertFails(
      setDoc(doc(driver(), 'admins', ATTACKER), { email: ATTACKER }),
    );
  });

  it('an unverified email cannot exercise admin power', async () => {
    // Firebase email/password signup does not prove ownership of an address,
    // so an admins/ document alone must not be enough.
    await seed(async (db) => {
      await setDoc(doc(db, 'admins', ATTACKER), { email: ATTACKER });
    });
    const unverified = driver(ATTACKER, ATTACKER_UID, false);
    await assertFails(
      updateDoc(doc(unverified, 'drivers', VICTIM), { status: 'suspended' }),
    );
  });

  it('a driver cannot suspend a rival', async () => {
    await assertFails(
      updateDoc(doc(driver(), 'drivers', VICTIM), { status: 'suspended' }),
    );
  });

  it('a driver cannot rewrite their own verification state', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'drivers', ATTACKER), profileOf(ATTACKER, 'suspended'));
    });
    await assertFails(
      updateDoc(doc(driver(), 'drivers', ATTACKER), { status: 'approved' }),
    );
  });

  it('a commuter cannot tamper with runtime config', async () => {
    // Changing searchRadiusKm or the fare table affects every user.
    await assertFails(
      setDoc(doc(commuter(), 'config', 'app'), { farePerKm: 0 }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('hijacking a ride', () => {
  it('a driver cannot steal a ride offered to someone else', async () => {
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'victim-ride'), {
        status: 'accepted',
        assignedDriver: ATTACKER,
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  it('a commuter cannot reassign their ride to a chosen driver', async () => {
    // assignedDriver is absent from every commuter clause.
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'victim-ride'), {
        assignedDriver: ATTACKER,
      }),
    );
  });

  it('a commuter cannot forge a completed ride to farm a rating', async () => {
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'victim-ride'), {
        status: 'completed',
        completedAt: serverTimestamp(),
      }),
    );
  });

  it('a commuter cannot attach a fare to a completed ride', async () => {
    // Fares were removed from the app entirely. No clause admits the key, so
    // writing one is refused rather than validated — which is what stops a
    // modified client from inventing a charge after the fact.
    await seed(async (db) => {
      await updateDoc(doc(db, 'rides', 'victim-ride'), {
        status: 'completed',
        assignedDriver: VICTIM,
      });
    });
    await assertFails(
      updateDoc(doc(commuter(), 'rides', 'victim-ride'), { fareEstimate: 5 }),
    );
  });

  it('a signed-in user cannot inflate a driver rating', async () => {
    // This was a documented, accepted gap until step 68. The rules could
    // verify the arithmetic of an increment — one vote, worth 1 to 5 — but
    // never tie it to a completed ride, because each document in a
    // transaction is authorised independently. Anyone signed in could
    // manufacture a reputation for any driver without taking a trip.
    //
    // `onRideRated` now owns the aggregate and derives the value from the
    // ride, so no client write of these fields is admitted at all. Both
    // shapes below were the attack; the first one used to succeed.
    await assertFails(
      updateDoc(doc(commuter(), 'drivers', VICTIM), {
        ratingSum: 5,
        ratingCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(commuter(), 'drivers', VICTIM), {
        ratingSum: 5000,
        ratingCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('a driver cannot inflate their own rating either', async () => {
    // The self-edit clause lists contact fields only, so the aggregate is
    // out of reach from the one context that most wants to reach it.
    await assertFails(
      updateDoc(doc(driver(), 'drivers', ATTACKER), {
        ratingSum: 5,
        ratingCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('a ride cannot be deleted to erase the audit trail', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'admins', ATTACKER), { email: ATTACKER });
    });
    // Not even an admin: rides are the analytics record.
    const { deleteDoc } = await import('firebase/firestore');
    await assertFails(deleteDoc(doc(driver(), 'rides', 'victim-ride')));
  });
});

// ════════════════════════════════════════════════════════════
// Tripwires on documented, accepted gaps.
// ════════════════════════════════════════════════════════════
describe('known gaps — asserted so they cannot change unnoticed', () => {
  it('GAP: a suspended driver can still publish presence', async () => {
    // Approval is checked at ride acceptance, not on every GPS ping — one
    // document read per ping, per driver, every few seconds is a real cost.
    // A suspended driver therefore appears in the dispatch index but cannot
    // accept anything offered to them.
    await seed(async (db) => {
      await setDoc(doc(db, 'drivers', ATTACKER), profileOf(ATTACKER, 'suspended'));
    });

    await assertSucceeds(
      setDoc(doc(driver(), 'active_drivers', ATTACKER), {
        email: ATTACKER,
        isOnline: true,
        availability: 'idle',
        position: {
          geohash: 'wdw2q1abc',
          geopoint: new GeoPoint(14.5995, 120.9842),
        },
        updatedAt: serverTimestamp(),
      }),
    );

    // The gate that actually matters still holds.
    await seed(async (db) => {
      await updateDoc(doc(db, 'rides', 'victim-ride'), {
        dispatch: {
          offeredTo: ATTACKER,
          offerSeq: 1,
          offerExpiresAt: null,
          attemptedDrivers: [ATTACKER],
          depth: 1,
        },
      });
    });
    await assertFails(
      updateDoc(doc(driver(), 'rides', 'victim-ride'), {
        status: 'accepted',
        assignedDriver: ATTACKER,
        acceptedAt: serverTimestamp(),
      }),
    );
  });

  it('GAP: any signed-in user can enumerate online driver emails', async () => {
    // The greedy search runs on the commuter's device, so it must be able to
    // query the dispatch index. That document deliberately carries no name,
    // phone, or plate — an email and a coordinate is the whole exposure.
    await seed(async (db) => {
      await setDoc(doc(db, 'active_drivers', VICTIM), {
        email: VICTIM,
        isOnline: true,
        availability: 'idle',
        position: {
          geohash: 'wdw2q1abc',
          geopoint: new GeoPoint(14.5995, 120.9842),
        },
        updatedAt: new Date(),
      });
    });

    const snap = await assertSucceeds(
      getDocs(collection(commuter(), 'active_drivers')),
    );
    const row = snap.docs[0].data();
    assert.equal(row.email, VICTIM);

    // What the row must never contain.
    for (const field of ['phone', 'plateNumber', 'firstName', 'lastName']) {
      assert.equal(row[field], undefined,
        `active_drivers must not expose ${field}`);
    }
  });
});
