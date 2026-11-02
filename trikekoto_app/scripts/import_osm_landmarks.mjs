// ============================================================
// Import named places from OpenStreetMap as landmarks
// ============================================================
//   npm install                          (once, in this folder)
//   node import_osm_landmarks.mjs        dry run: lists them, writes nothing
//   node import_osm_landmarks.mjs --commit
//   node import_osm_landmarks.mjs --remove   delete every imported landmark
//
//   --radius=8    kilometres around the service area (1 to 25); defaults to its radius
//
// Needs service-account.json here, as seed_admin.mjs does.
//
// Gives a chapter a starting list of real places, to which an admin adds the
// ones OSM does not have. IDs come from the OSM object, so running this again
// updates the same landmarks rather than doubling them. Landmarks added by hand
// are never touched: --remove deletes only those marked `source: 'osm'`.
//
// Map data (c) OpenStreetMap contributors, under the ODbL. The map already
// carries that attribution.
// ============================================================

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { FieldValue, GeoPoint, getFirestore } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const keyPath = resolve(here, 'service-account.json');
const commit = process.argv.includes('--commit');
const remove = process.argv.includes('--remove');
const radiusArg = process.argv.find((a) => a.startsWith('--radius='));
const radiusChoice = Number(radiusArg?.split('=')[1]);

if (!existsSync(keyPath)) {
  console.error('\n  service-account.json not found in trikekoto_app/scripts/.\n');
  process.exit(1);
}
initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
const db = getFirestore();

if (remove) {
  const found = await db.collection('landmarks').where('source', '==', 'osm').get();
  for (const doc of found.docs) await doc.ref.delete();
  console.log(`\nRemoved ${found.size} imported landmarks.\n`);
  process.exit(0);
}

// Mirrors ServiceArea.fallback in lib/core/config/app_config.dart.
const config = (await db.doc('config/app').get()).data();
const area = config?.serviceArea ?? {};
const lat = area.lat ?? 14.9321;
const lng = area.lng ?? 120.2005;
const label = area.label ?? 'Castillejos';

// OSM has no boundary for Castillejos, and a circle wide enough for its far
// barangays also reaches San Marcelino and Subic. So this box, drawn by hand
// around the barangays OSM does have, decides what is imported. It is an
// approximation. Look over the dry run, and delete any strays in the admin panel.
const inCastillejos = (p) =>
  p.lat >= 14.889 && p.lat <= 14.96 && p.lon >= 120.155 && p.lon <= 120.218;

// Names that would match a dozen places and tell a driver nothing.
const generic = /^(eatery|canteen|carinderia|store|clinic|church|catholic church|christian church|church of christ|baptist church|basketball court|covered court|court|school|elementary school|drug ?store|pharmacy|botika ng bayan|resort|chapel)$/i;

// The kinds of place people give directions by.
const kinds = [
  'amenity~"^(school|college|university|hospital|clinic|doctors|pharmacy|place_of_worship|marketplace|townhall|police|fire_station|community_centre|bank|fuel|bus_station|post_office|restaurant|fast_food|cafe)$"',
  'shop~"^(supermarket|mall|convenience|department_store|hardware)$"',
  'leisure~"^(park|stadium|sports_centre|pitch)$"',
  'office~"^(government)$"',
  'tourism~"^(attraction|hotel|resort)$"',
  'public_transport~"^(station)$"',
];
const radiusKm = Math.min(Math.max(radiusChoice || area.radiusKm || 8, 1), 25);
const metres = radiusKm * 1000;
const query = `[out:json][timeout:60];(${kinds
  .map((k) => `nwr[${k}]["name"](around:${metres},${lat},${lng});`)
  .join('')});out center tags;`;

// Public servers that are often busy, so each gets a few tries.
const servers = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];

async function fetchPlaces() {
  for (let attempt = 0; attempt < 6; attempt++) {
    const server = servers[attempt % servers.length];
    try {
      const response = await fetch(server, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'ph.trikekoto.trikekoto_app',
        },
        body: `data=${encodeURIComponent(query)}`,
      });
      if (response.ok) return (await response.json()).elements;
      console.error(`  ${new URL(server).host}: HTTP ${response.status}`);
    } catch (e) {
      console.error(`  ${new URL(server).host}: ${e.message}`);
    }
    await new Promise((done) => setTimeout(done, 5000 * (attempt + 1)));
  }
  console.error('\n  No Overpass server answered. Nothing was written.\n');
  process.exit(1);
}

const elements = await fetchPlaces();

/** One per name and spot: OSM often maps a place as both a building and a node. */
const seen = new Set();
const landmarks = [];
for (const e of elements) {
  const name = e.tags?.name?.trim();
  const point = e.type === 'node' ? { lat: e.lat, lon: e.lon } : e.center;
  if (!name || name.length > 80 || !point) continue;
  if (generic.test(name) || !inCastillejos(point)) continue;
  const key = `${name.toLowerCase()}|${point.lat.toFixed(3)}|${point.lon.toFixed(3)}`;
  if (seen.has(key)) continue;
  seen.add(key);
  landmarks.push({ id: `osm-${e.type}-${e.id}`, name, lat: point.lat, lng: point.lon });
}
landmarks.sort((a, b) => a.name.localeCompare(b.name));

console.log(`\n${landmarks.length} named places within ${radiusKm} km of ${label}:\n`);
for (const l of landmarks) {
  console.log(`  ${l.name}  (${l.lat.toFixed(4)}, ${l.lng.toFixed(4)})`);
}

if (!commit) {
  console.log('\nDry run: nothing was written. Add --commit to write them.\n');
  process.exit(0);
}

for (let i = 0; i < landmarks.length; i += 400) {
  const batch = db.batch();
  for (const l of landmarks.slice(i, i + 400)) {
    batch.set(db.collection('landmarks').doc(l.id), {
      name: l.name,
      point: new GeoPoint(l.lat, l.lng),
      source: 'osm',
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
console.log(`\nWritten: ${landmarks.length} landmarks.\n`);
process.exit(0);
