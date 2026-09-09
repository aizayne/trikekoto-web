// ============================================================
// Tests for the one-off web → Flutter data migration
// ============================================================
// This is the only script in the project that rewrites production data, and
// it runs once, against real drivers, with no undo. A bug here does not throw
// — it quietly writes a wrong status and a driver cannot work the next
// morning.
//
// Reading the script found one such bug already: 'Active' was missing from
// the status map, and an unmapped status falls through to 'pending', so every
// working driver in the chapter would have been silently demoted.
// ============================================================

import assert from 'node:assert/strict';

// Everything Firestore-shaped comes from the script's own module. This
// repository has three copies of firebase-admin, and GeoPoint/FieldValue are
// checked by identity — a value from one copy is refused by a Firestore from
// another, with an opaque error at write time.
import {
  connect,
  migrateDrivers,
  migrateActiveDrivers,
} from '../scripts/migrate_from_web.mjs';

const PROJECT_ID = 'trikekoto-rules-test';

let handle;
let db;
let Timestamp;
let GeoPoint;

before(async () => {
  // emulators:exec sets FIRESTORE_EMULATOR_HOST, which the Admin SDK honours,
  // so no credentials are needed and nothing can reach a real project.
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    'must run under the Firestore emulator',
  );
  handle = connect({ projectId: PROJECT_ID });
  db = handle.db;

  // Resolved through the script's dependency tree, not this package's.
  ({ Timestamp, GeoPoint } = await import(
    new URL('../scripts/node_modules/firebase-admin/lib/firestore/index.js',
      import.meta.url).href
  ));
});

after(async () => {
  if (handle) await handle.close();
});

async function wipe(collection) {
  const snap = await db.collection(collection).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

beforeEach(async () => {
  await wipe('drivers');
  await wipe('active_drivers');
});

/** A driver exactly as the React build wrote it. */
const legacyDriver = (overrides = {}) => ({
  email: 'juan@toda.ph',
  firstName: 'Juan',
  lastName: 'Dela Cruz',
  phone: '09171234567',
  plateNumber: 'ABC1234',
  status: 'Active',
  ...overrides,
});

// uid resolution goes through Auth in production. Stubbed here so these tests
// assert the migration's own logic rather than the emulator's user store.
const noUid = async () => {
  throw new Error('no Auth account');
};

async function runDrivers({ lookupUid = noUid } = {}) {
  return migrateDrivers(db, { commit: true, lookupUid });
}

describe('driver status mapping', () => {
  const cases = [
    ['Active', 'approved'],
    ['Pending Verification', 'pending'],
    ['Suspended', 'suspended'],
    ['Approved', 'approved'],
    ['Verified', 'approved'],
    ['Rejected', 'rejected'],
  ];

  for (const [legacy, expected] of cases) {
    it(`maps "${legacy}" to ${expected}`, async () => {
      await db.doc('drivers/juan@toda.ph').set(legacyDriver({ status: legacy }));
      await runDrivers();
      const after = (await db.doc('drivers/juan@toda.ph').get()).data();
      assert.equal(after.status, expected);
    });
  }

  it('does not demote a working driver — the bug this suite was written for',
    async () => {
      await db.doc('drivers/juan@toda.ph').set(legacyDriver({ status: 'Active' }));
      await runDrivers();
      const after = (await db.doc('drivers/juan@toda.ph').get()).data();
      assert.notEqual(after.status, 'pending');
      assert.equal(after.status, 'approved');
    });

  it('leaves an already-migrated status alone', async () => {
    await db.doc('drivers/juan@toda.ph').set(legacyDriver({ status: 'approved' }));
    await runDrivers();
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.status, 'approved');
  });

  it('sends an unrecognised status to pending rather than guessing', async () => {
    await db.doc('drivers/juan@toda.ph').set(legacyDriver({ status: 'Banana' }));
    await runDrivers();
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    // Re-verifying by hand is the safe failure. Guessing 'approved' would put
    // an unvetted driver on the road.
    assert.equal(after.status, 'pending');
  });

  it('treats a missing status as pending', async () => {
    const d = legacyDriver();
    delete d.status;
    await db.doc('drivers/juan@toda.ph').set(d);
    await runDrivers();
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.status, 'pending');
  });
});

describe('driver backfill', () => {
  it('adds the rating counters the Flutter model expects', async () => {
    await db.doc('drivers/juan@toda.ph').set(legacyDriver());
    await runDrivers();
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.ratingSum, 0);
    assert.equal(after.ratingCount, 0);
    assert.equal(after.todaChapter, '');
  });

  it('never overwrites ratings that already exist', async () => {
    await db.doc('drivers/juan@toda.ph').set(
      legacyDriver({ ratingSum: 42, ratingCount: 10 }),
    );
    await runDrivers();
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.ratingSum, 42);
    assert.equal(after.ratingCount, 10);
  });

  it('fills a missing email from the document id, lowercased', async () => {
    const d = legacyDriver();
    delete d.email;
    await db.doc('drivers/Juan@TODA.ph').set(d);
    await runDrivers();
    const after = (await db.doc('drivers/Juan@TODA.ph').get()).data();
    assert.equal(after.email, 'juan@toda.ph');
  });

  it('records the uid when Auth knows the account', async () => {
    await db.doc('drivers/juan@toda.ph').set(legacyDriver());
    await runDrivers({ lookupUid: async () => 'uid-123' });
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.uid, 'uid-123');
  });

  it('carries on when Auth has no account, rather than aborting the run',
    async () => {
      await db.doc('drivers/juan@toda.ph').set(legacyDriver());
      await db.doc('drivers/maria@toda.ph').set(
        legacyDriver({ email: 'maria@toda.ph', status: 'Suspended' }),
      );

      await runDrivers();

      // One missing Auth account must not stop the driver behind it in the
      // loop from being migrated.
      const maria = (await db.doc('drivers/maria@toda.ph').get()).data();
      assert.equal(maria.status, 'suspended');
    });
});

describe('dry run', () => {
  it('writes nothing', async () => {
    await db.doc('drivers/juan@toda.ph').set(legacyDriver({ status: 'Active' }));
    await migrateDrivers(db, { commit: false, lookupUid: noUid });
    const after = (await db.doc('drivers/juan@toda.ph').get()).data();
    assert.equal(after.status, 'Active');
  });
});

describe('presence documents', () => {
  const fresh = () => Timestamp.fromMillis(Date.now() - 60 * 1000);
  const stale = () => Timestamp.fromMillis(Date.now() - 40 * 60 * 60 * 1000);

  it('reshapes location into position with a geohash', async () => {
    await db.doc('active_drivers/juan@toda.ph').set({
      isOnline: true,
      location: { lat: 14.5995, lng: 120.9842, accuracy: 12 },
      updatedAt: fresh(),
    });

    await migrateActiveDrivers(db, { commit: true });

    const after = (await db.doc('active_drivers/juan@toda.ph').get()).data();
    assert.ok(after.position.geopoint);
    assert.equal(after.position.geopoint.latitude, 14.5995);
    assert.equal(after.position.geopoint.longitude, 120.9842);
    assert.equal(typeof after.position.geohash, 'string');
    assert.equal(after.position.geohash.length, 9);
    assert.equal(after.location, undefined, 'old shape must be removed');
  });

  it('keeps isOnline, which dispatch filters on', async () => {
    await db.doc('active_drivers/juan@toda.ph').set({
      isOnline: true,
      location: { lat: 14.6, lng: 121.0 },
      updatedAt: fresh(),
    });

    await migrateActiveDrivers(db, { commit: true });

    // The driver discovery query is
    // where('isOnline', ==, true) + availability + geohash. Losing this field
    // would leave a document that looks migrated and is never matched.
    const after = (await db.doc('active_drivers/juan@toda.ph').get()).data();
    assert.equal(after.isOnline, true);
    assert.equal(after.availability, 'idle');
  });

  it('produces a geohash the app would produce for the same point',
    async () => {
      // Both encoders default to precision 9 over the same alphabet. If they
      // ever diverge, prefix range queries silently return nothing.
      await db.doc('active_drivers/a@toda.ph').set({
        isOnline: true,
        location: { lat: 14.5995, lng: 120.9842 },
        updatedAt: fresh(),
      });
      await migrateActiveDrivers(db, { commit: true });
      const after = (await db.doc('active_drivers/a@toda.ph').get()).data();
      // Manila. Geohashes for nearby points share a long prefix.
      assert.ok(after.position.geohash.startsWith('wdw'),
        `unexpected geohash ${after.position.geohash}`);
    });

  it('drops a presence document older than a day', async () => {
    await db.doc('active_drivers/old@toda.ph').set({
      isOnline: true,
      location: { lat: 14.6, lng: 121.0 },
      updatedAt: stale(),
    });

    await migrateActiveDrivers(db, { commit: true });

    const after = await db.doc('active_drivers/old@toda.ph').get();
    assert.equal(after.exists, false, 'a cold presence row is worthless');
  });

  it('drops a document with no usable coordinates', async () => {
    await db.doc('active_drivers/broken@toda.ph').set({
      isOnline: true,
      location: { lat: 'not-a-number', lng: 121.0 },
      updatedAt: fresh(),
    });

    await migrateActiveDrivers(db, { commit: true });

    assert.equal(
      (await db.doc('active_drivers/broken@toda.ph').get()).exists,
      false,
    );
  });

  it('leaves an already-migrated document untouched', async () => {
    await db.doc('active_drivers/done@toda.ph').set({
      isOnline: true,
      availability: 'busy',
      position: { geohash: 'wdw4f9dkx', geopoint: new GeoPoint(14.6, 121.0) },
      updatedAt: fresh(),
    });

    const { converted } = await migrateActiveDrivers(db, { commit: true });

    assert.equal(converted, 0);
    const after = (await db.doc('active_drivers/done@toda.ph').get()).data();
    // Re-running the migration must be safe: it will be run more than once.
    assert.equal(after.availability, 'busy');
  });

  it('is idempotent across two runs', async () => {
    await db.doc('active_drivers/juan@toda.ph').set({
      isOnline: true,
      location: { lat: 14.5995, lng: 120.9842 },
      updatedAt: fresh(),
    });

    await migrateActiveDrivers(db, { commit: true });
    const first = (await db.doc('active_drivers/juan@toda.ph').get()).data();

    await migrateActiveDrivers(db, { commit: true });
    const second = (await db.doc('active_drivers/juan@toda.ph').get()).data();

    assert.deepEqual(second.position.geohash, first.position.geohash);
  });
});
