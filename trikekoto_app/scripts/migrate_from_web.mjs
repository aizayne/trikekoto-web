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

import { pathToFileURL } from 'node:url';
import { initializeApp, applicationDefault, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  GeoPoint,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

// The web build's three states are 'Pending Verification', 'Active' and
// 'Suspended' — see FILTER_OPTIONS in src/pages/AdminPanel.jsx. 'Active' is
// the one a working driver holds.
//
// It was missing here, and its absence was worse than a no-op: an unmapped
// status falls through to 'pending' below, so a migration run would have
// silently demoted every working driver in the chapter and required each to
// be re-verified by hand.
const STATUS_MAP = {
  'Pending Verification': 'pending',
  Pending: 'pending',
  Active: 'approved',
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

/**
 * A Firestore handle built from *this* module's copy of firebase-admin.
 *
 * Callers must not bring their own. `GeoPoint` and `FieldValue` are checked by
 * identity, so a value created here is rejected by a Firestore that came from
 * a different copy of the SDK — and this repository has three, one each under
 * scripts/, test_rules/ and the web project. The failure is an opaque
 * "doesn't match the expected instance" at write time.
 *
 * Pass `projectId` to talk to the emulator (FIRESTORE_EMULATOR_HOST is honoured
 * automatically); pass nothing to use the ambient service-account credentials.
 */
export function connect({ projectId } = {}) {
  const app = initializeApp(
    projectId ? { projectId } : { credential: applicationDefault() },
    `migrate-${Date.now()}-${Math.random().toString(36).slice(2)}`,
  );
  return { app, db: getFirestore(app), close: () => deleteApp(app) };
}

export async function migrateDrivers(db, { commit = false, lookupUid } = {}) {
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
        const resolve = lookupUid ??
            (async (email) => (await getAuth().getUserByEmail(email)).uid);
        patch.uid = await resolve(docSnap.id);
      } catch {
        console.warn(`  ! no Auth account for ${docSnap.id} — uid left unset`);
      }
    }

    if (Object.keys(patch).length === 0) continue;
    touched++;
    console.log(`  drivers/${docSnap.id}`, patch);
    if (commit) await docSnap.ref.update(patch);
  }

  console.log(`drivers: ${touched}/${snap.size} updated\n`);
  return touched;
}

export async function migrateActiveDrivers(db, { commit = false } = {}) {
  const snap = await db.collection('active_drivers').get();
  const cutoff = Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
  let converted = 0;
  let dropped = 0;

  for (const docSnap of snap.docs) {
    const d = docSnap.data();

    if (d.updatedAt && d.updatedAt.toMillis() < cutoff.toMillis()) {
      dropped++;
      console.log(`  drop active_drivers/${docSnap.id} (stale)`);
      if (commit) await docSnap.ref.delete();
      continue;
    }

    if (d.position?.geopoint) continue; // already migrated

    const lat = d.location?.lat;
    const lng = d.location?.lng;
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      dropped++;
      console.log(`  drop active_drivers/${docSnap.id} (no coordinates)`);
      if (commit) await docSnap.ref.delete();
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
    if (commit) await docSnap.ref.update(patch);
  }

  console.log(`active_drivers: ${converted} converted, ${dropped} dropped\n`);
  return { converted, dropped };
}

export async function reportRides(db) {
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

// CLI entry. Guarded so the functions above can be imported by tests without
// connecting to a real project or writing anything — this is the one script
// here that rewrites production data, and it had no tests at all.
const isMain = process.argv[1] &&
    import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const commit = process.argv.includes('--commit');
  if (!commit && !process.argv.includes('--dry-run')) {
    console.error('Pass --dry-run to preview, or --commit to write.');
    process.exit(1);
  }

  const { db } = connect();

  console.log(commit ? '── COMMITTING ──\n' : '── DRY RUN ──\n');
  await migrateDrivers(db, { commit });
  await migrateActiveDrivers(db, { commit });
  await reportRides(db);
  console.log(commit ? '\nDone.' : '\nDry run complete. Re-run with --commit to apply.');
}
