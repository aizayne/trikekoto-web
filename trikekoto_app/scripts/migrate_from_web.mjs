// ============================================================
// One-off migration: web build → Flutter schema
// ============================================================
//   node scripts/migrate_from_web.mjs --dry-run
//   node scripts/migrate_from_web.mjs --commit
//
// Requires a service-account key (Admin SDK bypasses security rules):
//   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
//
// What changes, and why
// ---------------------
//   drivers.status   'Pending Verification' → 'pending', 'Approved' → 'approved'
//                    Lowercase enums are comparable in security rules without
//                    worrying about display casing drifting over time.
//
//   drivers.*        Adds ratingSum/ratingCount/todaChapter so the create-time
//                    shape and the migrated shape agree.
//
//   rides            Left alone. Documents written by the web build have no
//                    commuterUid, so the new rules make them unreadable by
//                    anyone but an admin. That is the intent: they hold
//                    commuter names and phone numbers that were, until now,
//                    world-readable, and there is no uid to retroactively
//                    assign them to. Admins keep full access for analytics.
//
//   active_drivers   Reshapes {location:{lat,lng}} → {position:{geohash,geopoint}}.
//                    Stale rows (older than a day) are dropped rather than
//                    converted — a presence doc is worthless once cold.
// ============================================================

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  GeoPoint,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

const COMMIT = process.argv.includes('--commit');
if (!COMMIT && !process.argv.includes('--dry-run')) {
  console.error('Pass --dry-run to preview, or --commit to write.');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const STATUS_MAP = {
  'Pending Verification': 'pending',
  Pending: 'pending',
  Approved: 'approved',
  Verified: 'approved',
  Suspended: 'suspended',
  Rejected: 'rejected',
};

/** Geohash encoder — matches the geoflutterfire_plus / geofire alphabet. */
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';
function encodeGeohash(lat, lng, precision = 9) {
  let [latMin, latMax] = [-90, 90];
  let [lngMin, lngMax] = [-180, 180];
  let hash = '';
  let bit = 0;
  let ch = 0;
  let even = true;

  while (hash.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng > mid) {
        ch = (ch << 1) + 1;
        lngMin = mid;
      } else {
        ch <<= 1;
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat > mid) {
        ch = (ch << 1) + 1;
        latMin = mid;
      } else {
        ch <<= 1;
        latMax = mid;
      }
    }
    even = !even;
    if (++bit === 5) {
      hash += BASE32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

async function migrateDrivers() {
  const snap = await db.collection('drivers').get();
  let touched = 0;

  for (const docSnap of snap.docs) {
    const d = docSnap.data();
    const patch = {};

    const mapped = STATUS_MAP[d.status];
    if (mapped && mapped !== d.status) patch.status = mapped;
    else if (!mapped && !Object.values(STATUS_MAP).includes(d.status)) {
      patch.status = 'pending'; // unrecognised → re-verify by hand
    }

    if (typeof d.ratingSum !== 'number') patch.ratingSum = 0;
    if (typeof d.ratingCount !== 'number') patch.ratingCount = 0;
    if (typeof d.todaChapter !== 'string') patch.todaChapter = '';
    if (typeof d.email !== 'string') patch.email = docSnap.id.toLowerCase();

    // uid was never stored by the web build. It cannot be recovered from
    // Firestore; look it up in Auth so the field is honest rather than blank.
    if (typeof d.uid !== 'string') {
      try {
        const user = await getAuth().getUserByEmail(docSnap.id);
        patch.uid = user.uid;
      } catch {
        console.warn(`  ! no Auth account for ${docSnap.id} — uid left unset`);
      }
    }

    if (Object.keys(patch).length === 0) continue;
    touched++;
    console.log(`  drivers/${docSnap.id}`, patch);
    if (COMMIT) await docSnap.ref.update(patch);
  }

  console.log(`drivers: ${touched}/${snap.size} updated\n`);
}

async function migrateActiveDrivers() {
  const snap = await db.collection('active_drivers').get();
  const cutoff = Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  let converted = 0;
  let dropped = 0;

  for (const docSnap of snap.docs) {
    const d = docSnap.data();

    if (d.updatedAt && d.updatedAt.toMillis() < cutoff.toMillis()) {
      dropped++;
      console.log(`  drop active_drivers/${docSnap.id} (stale)`);
      if (COMMIT) await docSnap.ref.delete();
      continue;
    }

    if (d.position?.geopoint) continue; // already migrated

    const lat = d.location?.lat;
    const lng = d.location?.lng;
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      dropped++;
      console.log(`  drop active_drivers/${docSnap.id} (no coordinates)`);
      if (COMMIT) await docSnap.ref.delete();
      continue;
    }

    const patch = {
      email: docSnap.id.toLowerCase(),
      availability: d.availability ?? 'idle',
      position: { geohash: encodeGeohash(lat, lng), geopoint: new GeoPoint(lat, lng) },
      location: FieldValue.delete(),
    };

    converted++;
    console.log(`  active_drivers/${docSnap.id} → position{${patch.position.geohash}}`);
    if (COMMIT) await docSnap.ref.update(patch);
  }

  console.log(`active_drivers: ${converted} converted, ${dropped} dropped\n`);
}

async function reportRides() {
  const snap = await db.collection('rides').count().get();
  const orphaned = await db
    .collection('rides')
    .where('commuterUid', '==', null)
    .count()
    .get();
  console.log(
    `rides: ${snap.data().count} total; legacy documents stay admin-only ` +
      `(${orphaned.data().count} have an explicit null commuterUid).`,
  );
}

console.log(COMMIT ? '── COMMITTING ──\n' : '── DRY RUN ──\n');
await migrateDrivers();
await migrateActiveDrivers();
await reportRides();
console.log(COMMIT ? '\nDone.' : '\nDry run complete. Re-run with --commit to apply.');
