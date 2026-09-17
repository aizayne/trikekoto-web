// End-to-end check of event-driven dispatch, against the emulators.
//
//   cd trikekoto_app
//   npm --prefix functions run build
//   firebase emulators:exec --only functions,firestore --project demo-trikekoto \
//     "node functions/test/dispatch.emulator.mjs"
//
// Seeds four drivers around a pickup — the nearest one suspended — books two
// rides and watches the real triggers offer, move on after a decline, and
// move on when an offer lapses. Routing points at a closed port, so ranking
// falls back to straight-line distance and the test needs no network.
import { initializeApp } from 'firebase-admin/app';
import { GeoPoint, Timestamp, getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = getFirestore();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const lat = 14.9747, lng = 120.1577;
const at = (km) => new GeoPoint(lat + km / 111.2, lng);

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail ? ` (${detail})` : ''}`);
  if (!ok) failures++;
}

async function offeredTo(id) {
  return (await db.doc(`rides/${id}`).get()).data()?.dispatch?.offeredTo ?? null;
}

async function waitForOffer(id, notTo, ms) {
  const start = Date.now();
  while (Date.now() - start < ms) {
    const to = await offeredTo(id);
    if (to && to !== notTo) return { to, seconds: (Date.now() - start) / 1000 };
    await sleep(250);
  }
  return { to: await offeredTo(id), seconds: ms / 1000 };
}

await db.doc('config/app').set({
  // Long enough that no offer lapses by accident: the emulator runs triggers
  // far slower than production, tens of seconds apart on a cold Windows box.
  // The lapse check below shortens it on purpose.
  offerTimeoutSeconds: 90,
  searchRadiusKm: 5,
  maxDriversToTry: 10,
  routingBaseUrl: 'https://127.0.0.1:9',
});

const drivers = [
  ['suspended@toda.ph', 0.05, 'suspended'],
  ['a@toda.ph', 0.1, 'approved'],
  ['b@toda.ph', 0.4, 'approved'],
  ['c@toda.ph', 0.9, 'approved'],
  ['d@toda.ph', 1.5, 'approved'],
];
for (const [email, km, status] of drivers) {
  await db.doc(`drivers/${email}`).set({ email, status, firstName: 'T', phone: '0917', plateNumber: 'X1' });
  await db.doc(`active_drivers/${email}`).set({
    email, isOnline: true, availability: 'idle',
    position: { geohash: 'wdw', geopoint: at(km) },
    updatedAt: Timestamp.now(),
  });
}

const ride = (uid) => ({
  commuterUid: uid,
  commuterName: 'Test',
  commuterPhone: '09181234567',
  status: 'searching',
  serviceType: 'regular',
  pickup: { label: 'Plaza', geopoint: new GeoPoint(lat, lng) },
  dropoff: { label: 'Palengke', geopoint: at(2) },
  dispatch: { offeredTo: null, offerSeq: 0, offerExpiresAt: null, attemptedDrivers: [], depth: 0 },
  assignedDriver: null,
  rating: null,
  createdAt: Timestamp.now(),
});

// 1. A booking is offered by the trigger, to the nearest approved driver.
await db.doc('rides/r1').set(ride('u1'));
let r = await waitForOffer('r1', null, 60000);
check('a booking is offered without the app asking', r.to !== null, `${r.seconds}s in the emulator`);
check('the nearest APPROVED driver gets it; the suspended one does not', r.to === 'a@toda.ph', r.to);

// 2. A second booking at the same spot skips the driver already holding one.
await db.doc('rides/r2').set(ride('u2'));
r = await waitForOffer('r2', null, 60000);
check('a driver holding an offer is not offered a second ride', r.to === 'b@toda.ph', r.to);

// 3. A decline moves r1 on at once — to c, since a declined and b is busy
//    with r2.
const r1 = (await db.doc('rides/r1').get()).data();
check('r1 is still on its first offer before the decline',
  r1.dispatch.offeredTo === 'a@toda.ph' && r1.dispatch.attemptedDrivers.length === 1,
  JSON.stringify(r1.dispatch.attemptedDrivers));
await db.doc('rides/r1').update({
  dispatch: {
    offeredTo: null,
    offerSeq: r1.dispatch.offerSeq,
    offerExpiresAt: null,
    attemptedDrivers: r1.dispatch.attemptedDrivers,
    depth: r1.dispatch.depth,
  },
});
r = await waitForOffer('r1', 'a@toda.ph', 60000);
check('a decline offers the next FREE driver straight away', r.to === 'c@toda.ph', `${r.to}, ${r.seconds}s`);
// Timing is reported, not asserted: emulator latency says nothing about production.
console.log(`INFO decline to next offer took ${r.seconds}s in the emulator`);

// 4. A 5-second offer nobody answers. r3 goes to a (free again after
//    declining r1); when that lapses it moves to d, the only driver left
//    who is neither tried nor busy.
await db.doc('config/app').update({ offerTimeoutSeconds: 5 });
await db.doc('rides/r3').set(ride('u3'));
r = await waitForOffer('r3', null, 60000);
check('r3 is offered to the free driver first', r.to === 'a@toda.ph', r.to);
r = await waitForOffer('r3', 'a@toda.ph', 60000);
check('an unanswered offer moves on when it lapses', r.to === 'd@toda.ph', `${r.to}, ${r.seconds}s`);
// No sweep runs in the emulator (no Pub/Sub), so any move here came from the
// lapse path, not from sweepStaleRides.
console.log(`INFO lapse to next offer took ${r.seconds}s in the emulator`);

console.log(failures === 0 ? 'ALL PASS' : `${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
