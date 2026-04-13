// ============================================================
// seed-admin.mjs — TrikeKoTo admin bootstrap
// ============================================================
// Creates an `admins/{email}` document so a user can access the
// Admin Panel. Run this once per admin you want to grant, then
// never again (rules block all client writes to /admins).
//
// Prereqs
// -------
// 1. Generate a service account private key:
//      Firebase Console → Project Settings → Service Accounts
//      → "Generate new private key" → save as service-account.json
//      in the project root (it is already git-ignored).
// 2. Run:
//      node scripts/seed-admin.mjs jeloooaceee@gmail.com
//    Or with multiple:
//      node scripts/seed-admin.mjs foo@bar.com baz@qux.com
// ============================================================

import { existsSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT      = resolve(__dirname, "..");
const KEY_PATH  = resolve(ROOT, "service-account.json");

if (!existsSync(KEY_PATH)) {
  console.error(
    "\n✗ service-account.json not found.\n\n" +
    "  Generate one at:\n" +
    "    Firebase Console → Project Settings → Service Accounts\n" +
    "    → Generate new private key\n\n" +
    "  Save it to the project root as service-account.json.\n" +
    "  (It is already git-ignored.)\n"
  );
  process.exit(1);
}

const emails = process.argv.slice(2);
if (emails.length === 0) {
  console.error(
    "\n✗ Usage: node scripts/seed-admin.mjs <email> [<email> ...]\n" +
    "  Example: node scripts/seed-admin.mjs jeloooaceee@gmail.com\n"
  );
  process.exit(1);
}

// ── Init ─────────────────────────────────────────────────────
const serviceAccount = JSON.parse(readFileSync(KEY_PATH, "utf8"));
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// ── Seed ─────────────────────────────────────────────────────
let ok = 0;
for (const email of emails) {
  const normalized = email.trim().toLowerCase();
  try {
    await db.collection("admins").doc(normalized).set(
      {
        email: normalized,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: "seed-admin.mjs",
      },
      { merge: true }
    );
    console.log(`  ✓ admins/${normalized}`);
    ok += 1;
  } catch (err) {
    console.error(`  ✗ ${normalized}: ${err.message}`);
  }
}

console.log(`\n${ok}/${emails.length} admin doc(s) written.`);
process.exit(ok === emails.length ? 0 : 1);
