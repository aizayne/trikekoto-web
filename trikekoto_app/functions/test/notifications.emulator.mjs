// End-to-end check of the approval notice, against the emulators.
//
//   cd trikekoto_app
//   npm --prefix functions run build
//   firebase emulators:exec --only functions,firestore --project demo-trikekoto \
//     "node functions/test/notifications.emulator.mjs"
//
// Approves a driver the way the admin dashboard does — one field on the
// profile — and watches the real trigger write the notice the app reads back.
// No FCM token is seeded: a driver waiting on approval has never been online,
// which is the case the document exists for.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const db = getFirestore();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${label}${detail ? ` (${detail})` : ''}`);
  if (!ok) failures++;
}

const EMAIL = 'juan@toda.ph';
const UID = 'driver-uid-1';
const NOTICE = 'account_approved';

const noticeRef = (uid = UID) =>
  db.doc(`notifications/${uid}/items/${NOTICE}`);

async function waitForNotice(uid, ms) {
  const start = Date.now();
  while (Date.now() - start < ms) {
    const snap = await noticeRef(uid).get();
    if (snap.exists) return snap.data();
    await sleep(250);
  }
  return null;
}

async function seedDriver({ email = EMAIL, uid = UID, status = 'pending' } = {}) {
  await db.doc(`drivers/${email}`).set({
    email,
    uid,
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    phone: '09171234567',
    plateNumber: 'ABC1234',
    todaChapter: 'Barangay Uno TODA',
    status,
    createdAt: new Date(),
  });
}

async function main() {
  // ── An admin approves a pending driver ───────────────────────────────
  await seedDriver();
  await db.doc(`drivers/${EMAIL}`).update({ status: 'approved' });

  const notice = await waitForNotice(UID, 15_000);
  check('approving a driver writes them a notice', notice !== null);
  check(
    'it says what the specification says',
    notice?.body ===
      'Your account has been approved by the admin. You can now log in.',
    notice?.body ?? 'no notice',
  );
  check('it arrives unread', notice?.readAt === null, String(notice?.readAt));
  check('it carries its type', notice?.type === NOTICE, notice?.type ?? '');

  // ── A profile rewritten while already approved says nothing new ──────
  const firstWrittenAt = notice?.createdAt?.toMillis?.() ?? 0;
  await noticeRef().update({ readAt: new Date() });
  await db.doc(`drivers/${EMAIL}`).update({ ratingCount: 1, ratingSum: 5 });
  await sleep(4000);

  const after = (await noticeRef().get()).data();
  check(
    'a later edit to the profile does not re-notify',
    after?.readAt !== null &&
      (after?.createdAt?.toMillis?.() ?? 0) === firstWrittenAt,
    'notice was rewritten',
  );

  // ── A suspension, then a re-approval, is news again ──────────────────
  await db.doc(`drivers/${EMAIL}`).update({ status: 'suspended' });
  await sleep(2000);
  const afterSuspension = (await noticeRef().get()).data();
  check(
    'a suspension writes nothing',
    afterSuspension?.readAt !== null,
    'notice changed on suspension',
  );

  await db.doc(`drivers/${EMAIL}`).update({ status: 'approved' });
  const start = Date.now();
  let reNotified = false;
  while (Date.now() - start < 15_000) {
    const row = (await noticeRef().get()).data();
    if (row?.readAt === null) {
      reNotified = true;
      break;
    }
    await sleep(250);
  }
  check('being approved again is news again', reNotified);

  // ── A profile with no uid has nowhere to send a notice ───────────────
  await db.doc('drivers/nouid@toda.ph').set({
    email: 'nouid@toda.ph',
    firstName: 'Legacy',
    lastName: 'Driver',
    status: 'pending',
    createdAt: new Date(),
  });
  await db.doc('drivers/nouid@toda.ph').update({ status: 'approved' });
  await sleep(4000);
  const orphans = await db.collectionGroup('items').get();
  check(
    'a profile with no uid is approved without a notice, not with a stray one',
    orphans.docs.every((d) => d.ref.path.includes(`/${UID}/`)),
    orphans.docs.map((d) => d.ref.path).join(', '),
  );

  console.log(failures === 0 ? '\nALL PASS' : `\n${failures} FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
