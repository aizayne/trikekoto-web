// ============================================================
// Reserve the numbers of accounts that already exist
// ============================================================
//   npm install                                (once, in this folder)
//   node backfill_phone_claims.mjs             (dry run: changes nothing)
//   node backfill_phone_claims.mjs --commit
//
// Needs service-account.json here, as seed_admin.mjs does.
//
// Run this BEFORE deploying the rules that require phone claims. Accounts made
// before those rules hold no claim, so without this a new account could take a
// number that is already in use.
//
// Commuters go first: their numbers were proven by a code, and drivers' numbers
// were only typed. A number held by two accounts is reported, not resolved. The
// first keeps the claim and the other account keeps working, but an officer
// should decide which one is right.
// ============================================================

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const keyPath = resolve(here, 'service-account.json');
const commit = process.argv.includes('--commit');

if (!existsSync(keyPath)) {
  console.error('\n  service-account.json not found in trikekoto_app/scripts/.\n');
  process.exit(1);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
const db = getFirestore();

/** Mirrors toE164Ph in lib/features/commuter/data/phone_number.dart. */
function toE164Ph(raw) {
  const digits = String(raw ?? '').replace(/[^0-9+]/g, '');
  if (digits.startsWith('+63') && digits.length === 13) return digits;
  if (digits.startsWith('09') && digits.length === 11) return `+63${digits.slice(1)}`;
  if (digits.startsWith('9') && digits.length === 10) return `+63${digits}`;
  return null;
}

const mask = (phone) => `${phone.slice(0, 3)}•••••••${phone.slice(-4)}`;

const claims = new Map();
for (const snap of (await db.collection('phone_claims').get()).docs) {
  claims.set(snap.id, snap.data().uid);
}

const planned = [];
let unusable = 0;
let duplicates = 0;

function consider(phone, uid, role, label) {
  if (!phone || !uid) {
    unusable++;
    console.log(`  no usable number or uid: ${label}`);
    return;
  }
  const holder = claims.get(phone);
  if (holder === uid) return;
  if (holder) {
    duplicates++;
    console.log(`  already held by another account: ${mask(phone)} (${label})`);
    return;
  }
  claims.set(phone, uid);
  planned.push({ phone, uid, role });
}

for (const snap of (await db.collection('riders').get()).docs) {
  consider(toE164Ph(snap.data().phone), snap.id, 'rider', `rider ${snap.id}`);
}
for (const snap of (await db.collection('drivers').get()).docs) {
  const d = snap.data();
  consider(toE164Ph(d.phone), d.uid, 'driver', `driver ${snap.id}`);
}

console.log(
  `\n${planned.length} to add, ${duplicates} duplicates, ${unusable} unusable.`,
);

if (!commit) {
  console.log('Dry run: nothing was written. Add --commit to write them.\n');
  process.exit(0);
}

for (const { phone, uid, role } of planned) {
  await db.collection('phone_claims').doc(phone).set({
    uid,
    role,
    createdAt: FieldValue.serverTimestamp(),
  });
}
console.log('Written.\n');
