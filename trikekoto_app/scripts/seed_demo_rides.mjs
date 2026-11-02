// ============================================================
// Sample ride history, for demos and for trying the admin screens
// ============================================================
//   npm install                       (once, in this folder)
//   node seed_demo_rides.mjs          dry run: shows the plan, writes nothing
//   node seed_demo_rides.mjs --commit add them (--count=30 by default)
//   node seed_demo_rides.mjs --remove delete every sample ride
//
// Needs service-account.json here, as seed_admin.mjs does.
//
// REMOVE THESE BEFORE THE PILOT. They appear in the admin ride history and in
// analytics, where they would be counted as real service.
//
// What keeps them separate from real rides:
//   - each carries `demo: true`, and --remove deletes only those
//   - IDs are demo-ride-001 and so on, so running this twice rewrites the same
//     rides rather than doubling them
//   - names, numbers and accounts are made up and linked to nobody, so they do
//     not appear in any real commuter's or driver's history
//   - `ratingCounted` is set, and no driver's rating totals are touched
// ============================================================

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { GeoPoint, getFirestore, Timestamp } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const keyPath = resolve(here, 'service-account.json');
const commit = process.argv.includes('--commit');
const remove = process.argv.includes('--remove');
const countArg = process.argv.find((a) => a.startsWith('--count='));
const count = Math.min(Math.max(Number(countArg?.split('=')[1]) || 30, 1), 200);
const onEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

if (onEmulator) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'trikekoto-demo' });
} else if (existsSync(keyPath)) {
  initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
} else if (commit || remove) {
  console.error('\n  service-account.json not found in trikekoto_app/scripts/.\n');
  process.exit(1);
}

const places = [
  ['Sample: Plaza', 14.9747, 120.1577],
  ['Sample: Palengke', 14.9771, 120.1602],
  ['Sample: Barangay Hall', 14.9722, 120.1551],
  ['Sample: Elementary School', 14.9698, 120.1623],
  ['Sample: Health Center', 14.9789, 120.1548],
  ['Sample: TODA Terminal', 14.9755, 120.1639],
  ['Sample: Covered Court', 14.9714, 120.1596],
];

const comments = [
  'Mabait ang driver.',
  'Mabilis dumating.',
  'Malinis ang tricycle.',
  'Medyo natagalan pero okay naman.',
  'Salamat po!',
];

/** Repeatable, so a re-run produces the same history rather than a new one. */
function randomFrom(seed) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

const minutes = (date, n) => new Date(date.getTime() + n * 60_000);
const stamp = (date) => Timestamp.fromDate(date);
const emptyDispatch = {
  offeredTo: null,
  offerSeq: 0,
  offerExpiresAt: null,
  attemptedDrivers: [],
  depth: 0,
};

function buildRide(i, now) {
  const random = randomFrom(i * 7919 + 13);
  const pick = (list) => list[Math.floor(random() * list.length)];
  const from = pick(places);
  const to = pick(places.filter((p) => p !== from));
  const commuter = (i % 8) + 1;
  const driver = (i % 4) + 1;

  // Spread over the last 30 days, in the hours a tricycle is working.
  const created = new Date(now.getTime() - (1 + random() * 29) * 86_400_000);
  created.setHours(6 + Math.floor(random() * 14), Math.floor(random() * 60), 0, 0);

  const roll = random();
  const status =
    roll < 0.75 ? 'completed' : roll < 0.87 ? 'cancelled' : 'expired';

  const ride = {
    demo: true,
    commuterUid: `demo-commuter-${commuter}`,
    commuterName: `Sample Commuter ${commuter}`,
    commuterPhone: `+63900000000${commuter}`,
    commuterPhotoUrl: null,
    commuterFcmToken: null,
    pickup: { label: from[0], geopoint: new GeoPoint(from[1], from[2]) },
    dropoff: { label: to[0], geopoint: new GeoPoint(to[1], to[2]) },
    serviceType: random() < 0.15 ? 'special' : 'regular',
    notes: null,
    status,
    dispatch: emptyDispatch,
    assignedDriver: null,
    driverSnapshot: null,
    driverLocation: null,
    driverLocationAt: null,
    scheduledFor: null,
    rating: null,
    feedback: null,
    createdAt: stamp(created),
  };

  if (status === 'expired') {
    return {
      ...ride,
      cancelledBy: 'system',
      cancelledAt: stamp(minutes(created, 5)),
    };
  }

  const cancelledEarly = status === 'cancelled' && random() < 0.5;
  if (cancelledEarly) {
    return {
      ...ride,
      cancelledBy: 'commuter',
      cancelledAt: stamp(minutes(created, 1 + random() * 3)),
    };
  }

  const accepted = minutes(created, 0.5 + random() * 2);
  const email = `demo.driver${driver}@example.invalid`;
  const assigned = {
    ...ride,
    assignedDriver: email,
    acceptedAt: stamp(accepted),
    driverSnapshot: {
      email,
      firstName: `Sample Driver ${driver}`,
      phone: `+63900000010${driver}`,
      plateNumber: `DEMO${driver}00`,
      ratingSum: 0,
      ratingCount: 0,
    },
  };

  if (status === 'cancelled') {
    return {
      ...assigned,
      cancelledBy: random() < 0.5 ? 'driver' : 'commuter',
      cancelledAt: stamp(minutes(accepted, 2 + random() * 5)),
    };
  }

  const started = minutes(accepted, 3 + random() * 7);
  const completed = minutes(started, 5 + random() * 15);
  // Most people rate well, and not everyone rates at all.
  const rated = random() < 0.8;
  const rating = rated ? [3, 4, 4, 5, 5, 5, 5][Math.floor(random() * 7)] : null;
  return {
    ...assigned,
    startedAt: stamp(started),
    completedAt: stamp(completed),
    rating,
    feedback: rated && random() < 0.4 ? pick(comments) : null,
    ratedAt: rated ? stamp(minutes(completed, 2)) : null,
    ratingCounted: rated,
  };
}

async function deleteAll(db) {
  let removed = 0;
  for (;;) {
    const page = await db.collection('rides').where('demo', '==', true).limit(400).get();
    if (page.empty) return removed;
    const batch = db.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
    removed += page.size;
  }
}

const target = onEmulator ? 'the emulator' : 'the LIVE database';

if (remove) {
  console.log(`\nRemoved ${await deleteAll(getFirestore())} sample rides from ${target}.\n`);
  process.exit(0);
}

const now = new Date();
const rides = Array.from({ length: count }, (_, i) => buildRide(i, now));
const tally = {};
for (const r of rides) tally[r.status] = (tally[r.status] ?? 0) + 1;
console.log(`\n${count} sample rides:`, tally);

if (!commit) {
  console.log('Dry run: nothing was written. Add --commit to write them.\n');
  process.exit(0);
}

const db = getFirestore();
for (let i = 0; i < rides.length; i += 400) {
  const batch = db.batch();
  rides.slice(i, i + 400).forEach((ride, j) => {
    const id = `demo-ride-${String(i + j + 1).padStart(3, '0')}`;
    batch.set(db.collection('rides').doc(id), ride);
  });
  await batch.commit();
}
console.log(`Written to ${target}. Remove them before the pilot with --remove.\n`);
process.exit(0);
