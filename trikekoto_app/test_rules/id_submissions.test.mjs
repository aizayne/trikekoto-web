// ============================================================
// Government ID submission rules — id_submissions/{uid}
// ============================================================
// This collection holds sensitive personal information under RA 10173, and
// it is the only place in the schema that does. The rules are written to a
// stricter standard than the rest, and these tests exist so that standard
// cannot erode by accident.
//
// Four properties matter more than the happy path:
//
//   1. Nobody reads someone else's ID. Not another rider, not the driver
//      they are riding with, not a signed-in stranger.
//   2. Nobody approves their own. `status` is forced to 'pending' on create
//      and only an admin may move it.
//   3. A reviewer records a decision and cannot alter the submission, so a
//      rejected ID cannot be edited into an approved one.
//   4. Consent is recorded, not assumed. A submission with no consent
//      timestamp is refused, because without one there is no evidence it
//      was ever given.
// ============================================================

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from 'firebase/firestore';

const PROJECT_ID = 'trikekoto-ids-test';

const RIDER_UID = 'rider-uid-1';
const RIDER_PHONE = '+639171234567';
const OTHER_UID = 'rider-uid-2';
const DRIVER_UID = 'driver-uid-1';
const DRIVER_EMAIL = 'driver.one@toda.ph';
const ADMIN_EMAIL = 'admin@trikekoto.ph';

let testEnv;

const rider = (uid = RIDER_UID, phone = RIDER_PHONE) =>
  testEnv
    .authenticatedContext(uid, { phone_number: phone, provider_id: 'phone' })
    .firestore();

const driver = (uid = DRIVER_UID, email = DRIVER_EMAIL) =>
  testEnv
    .authenticatedContext(uid, { email, email_verified: true })
    .firestore();

const admin = () =>
  testEnv
    .authenticatedContext('admin-uid-1', {
      email: ADMIN_EMAIL,
      email_verified: true,
    })
    .firestore();

/** An admin whose address is unconfirmed — isAdmin() must refuse them. */
const unverifiedAdmin = () =>
  testEnv
    .authenticatedContext('admin-uid-2', {
      email: ADMIN_EMAIL,
      email_verified: false,
    })
    .firestore();

const anon = () => testEnv.unauthenticatedContext().firestore();

const submission = (uid = RIDER_UID, overrides = {}) => ({
  subjectUid: uid,
  role: 'rider',
  idType: 'national_id',
  idNumber: '1234-5678-9012',
  idPhotoPath: 'ids/' + uid + '/card',
  status: 'pending',
  consentAt: serverTimestamp(),
  submittedAt: serverTimestamp(),
  ...overrides,
});

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

async function seedSubmission(uid = RIDER_UID, fields = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'id_submissions', uid), {
      subjectUid: uid,
      role: 'rider',
      idType: 'national_id',
      idNumber: '1234-5678-9012',
      idPhotoPath: 'ids/' + uid + '/card',
      status: 'pending',
      consentAt: new Date(),
      submittedAt: new Date(),
      ...fields,
    });
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'admins', ADMIN_EMAIL), { email: ADMIN_EMAIL });
  });
});

// ════════════════════════════════════════════════════════════
describe('submitting an ID', () => {
  it('a rider may submit their own', async () => {
    await assertSucceeds(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID), submission()),
    );
  });

  it('a driver may submit their own', async () => {
    await assertSucceeds(
      setDoc(doc(driver(), 'id_submissions', DRIVER_UID),
        submission(DRIVER_UID, { role: 'driver' })),
    );
  });

  it('refuses a submission made for somebody else', async () => {
    // The document id IS the subject. Writing to another uid is the whole
    // impersonation risk in one line.
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', OTHER_UID), submission(OTHER_UID)),
    );
  });

  it('refuses a subjectUid that disagrees with the document id', async () => {
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { subjectUid: OTHER_UID })),
    );
  });

  it('refuses an unauthenticated submission', async () => {
    await assertFails(
      setDoc(doc(anon(), 'id_submissions', RIDER_UID), submission()),
    );
  });

  it('cannot arrive already approved', async () => {
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { status: 'approved' })),
    );
  });

  it('cannot arrive carrying a reviewer', async () => {
    // Otherwise a submission could name an admin who never saw it.
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { reviewedBy: ADMIN_EMAIL })),
    );
  });

  it('refuses a submission with no consent timestamp', async () => {
    const s = submission();
    delete s.consentAt;
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID), s),
    );
  });

  it('refuses a back-dated consent timestamp', async () => {
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { consentAt: new Date('2020-01-01') })),
    );
  });

  it('refuses a photo path pointing at someone else', async () => {
    // The path is pinned to the subject's uid, so a submission cannot cite
    // an image belonging to another person.
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { idPhotoPath: 'ids/' + OTHER_UID + '/card' })),
    );
  });

  it('refuses an unknown role', async () => {
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { role: 'admin' })),
    );
  });

  it('refuses an implausibly short ID number', async () => {
    await assertFails(
      setDoc(doc(rider(), 'id_submissions', RIDER_UID),
        submission(RIDER_UID, { idNumber: '12' })),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('reading an ID', () => {
  beforeEach(async () => seedSubmission());

  it('the subject can read their own', async () => {
    await assertSucceeds(getDoc(doc(rider(), 'id_submissions', RIDER_UID)));
  });

  it('an admin can read it', async () => {
    await assertSucceeds(getDoc(doc(admin(), 'id_submissions', RIDER_UID)));
  });

  it('another rider cannot', async () => {
    await assertFails(
      getDoc(doc(rider(OTHER_UID, '+639998887777'), 'id_submissions', RIDER_UID)),
    );
  });

  it('a driver cannot read a commuter ID', async () => {
    // A driver sees the passenger's name and photo on the ride. Their
    // government ID is a different order of exposure, and is never theirs.
    await assertFails(getDoc(doc(driver(), 'id_submissions', RIDER_UID)));
  });

  it('nobody unauthenticated can', async () => {
    await assertFails(getDoc(doc(anon(), 'id_submissions', RIDER_UID)));
  });

  it('an admin with an unconfirmed address cannot', async () => {
    // Same gate as the rest of the admin surface: the rules read the token,
    // not the admins document alone.
    await assertFails(
      getDoc(doc(unverifiedAdmin(), 'id_submissions', RIDER_UID)),
    );
  });

  it('only an admin can list the queue', async () => {
    await assertSucceeds(getDocs(collection(admin(), 'id_submissions')));
    await assertFails(getDocs(collection(rider(), 'id_submissions')));
    await assertFails(getDocs(collection(driver(), 'id_submissions')));
  });
});

// ════════════════════════════════════════════════════════════
describe('reviewing an ID', () => {
  beforeEach(async () => seedSubmission());

  it('an admin can approve', async () => {
    await assertSucceeds(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'approved',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
      }),
    );
  });

  it('an admin can reject with a reason', async () => {
    await assertSucceeds(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'rejected',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
        rejectionReason: 'Photo is too blurry to read the number.',
      }),
    );
  });

  it('cannot reject without saying why', async () => {
    // A rejection the subject cannot act on is a dead end for them.
    await assertFails(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'rejected',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
      }),
    );
  });

  it('the subject cannot approve their own', async () => {
    await assertFails(
      updateDoc(doc(rider(), 'id_submissions', RIDER_UID), {
        status: 'approved',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
      }),
    );
  });

  it('a reviewer cannot alter what was submitted', async () => {
    // The point of a review is the submitted content. If approving could
    // rewrite the ID number, the approval would mean nothing.
    await assertFails(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'approved',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
        idNumber: '9999-9999-9999',
      }),
    );
  });

  it('a reviewer cannot sign the decision as somebody else', async () => {
    await assertFails(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'approved',
        reviewedBy: 'someone.else@trikekoto.ph',
        reviewedAt: serverTimestamp(),
      }),
    );
  });

  it('a decided submission cannot be decided again', async () => {
    // Re-review would let a rejection quietly become an approval with no
    // trace of the first decision.
    await seedSubmission(RIDER_UID, {
      status: 'rejected',
      reviewedBy: ADMIN_EMAIL,
      reviewedAt: new Date(),
      rejectionReason: 'Expired.',
    });
    await assertFails(
      updateDoc(doc(admin(), 'id_submissions', RIDER_UID), {
        status: 'approved',
        reviewedBy: ADMIN_EMAIL,
        reviewedAt: serverTimestamp(),
      }),
    );
  });

  it('the subject cannot edit a submitted ID', async () => {
    await assertFails(
      updateDoc(doc(rider(), 'id_submissions', RIDER_UID), {
        idNumber: '0000-0000-0000',
      }),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('withdrawal and retention', () => {
  beforeEach(async () => seedSubmission());

  it('the subject can delete their own submission', async () => {
    // Withdrawing consent has to be something a person can do, not
    // something they have to ask for.
    await assertSucceeds(deleteDoc(doc(rider(), 'id_submissions', RIDER_UID)));
  });

  it('an admin can delete it, which is how retention is enforced', async () => {
    await assertSucceeds(deleteDoc(doc(admin(), 'id_submissions', RIDER_UID)));
  });

  it('a stranger cannot delete it', async () => {
    await assertFails(
      deleteDoc(doc(rider(OTHER_UID, '+639998887777'),
        'id_submissions', RIDER_UID)),
    );
  });
});
