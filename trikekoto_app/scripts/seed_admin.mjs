// ============================================================
// Bootstrap an admin account
// ============================================================
//   npm install                       (once, in this folder)
//   node seed_admin.mjs <email> <password>
//
// Needs a service-account key:
//   Firebase Console → Project Settings → Service Accounts
//   → Generate new private key → save as service-account.json here
//
// Why this exists rather than "just do it in the Console"
// -------------------------------------------------------
//   `isAdmin()` requires `request.auth.token.email_verified == true`,
//   because Firebase email/password signup does not prove you own the
//   address you typed. The Console has no toggle for that flag, so an
//   admin created by hand can authenticate but is refused by every
//   admin rule — a confusing failure that looks like broken rules.
//
//   This script creates (or repairs) the Auth user with emailVerified
//   set, then writes the admins/{email} document that grants the role.
// ============================================================

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const keyPath = resolve(here, 'service-account.json');

if (!existsSync(keyPath)) {
  console.error(
    '\n  service-account.json not found in trikekoto_app/scripts/.\n\n' +
      '  Firebase Console -> Project Settings -> Service Accounts\n' +
      '  -> Generate new private key -> save it here.\n',
  );
  process.exit(1);
}

const [email, password] = process.argv.slice(2);
if (!email || !password) {
  console.error('\n  Usage: node seed_admin.mjs <email> <password>\n');
  process.exit(1);
}

const normalized = email.trim().toLowerCase();

initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
const auth = getAuth();
const db = getFirestore();

let user;
try {
  user = await auth.getUserByEmail(normalized);
  console.log(`  Found existing account ${normalized}`);
  if (!user.emailVerified) {
    await auth.updateUser(user.uid, { emailVerified: true });
    console.log('  Marked email as verified');
  }
} catch (err) {
  if (err.code !== 'auth/user-not-found') throw err;
  user = await auth.createUser({
    email: normalized,
    password,
    emailVerified: true,
  });
  console.log(`  Created account ${normalized}`);
}

await db.collection('admins').doc(normalized).set(
  {
    email: normalized,
    displayName: normalized.split('@')[0],
    createdAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

console.log(`  Wrote admins/${normalized}`);
console.log('\n  Done. Sign in with these credentials in the app.\n');
process.exit(0);
