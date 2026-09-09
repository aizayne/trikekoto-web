// ============================================================
// Rider account rules — riders/{uid}
// ============================================================
// Rider accounts are optional: booking works with no account at all. What
// these assert is that adding one grants a name and a saved-address list and
// *nothing else* — a rider is a commuter with a profile, not a new privilege
// level.
//
// The phone number is the sensitive part. It is proven by the Auth token and
// must never be settable from a form, guessable from a document ID, or
// readable by anyone but its owner.
// ============================================================

import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
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

const PROJECT_ID = 'trikekoto-riders-test';

const RIDER_UID = 'rider-uid-1';
const RIDER_PHONE = '+639171234567';
const OTHER_UID = 'rider-uid-2';
const OTHER_PHONE = '+639998887777';
const DRIVER_EMAIL = 'driver.one@toda.ph';
const ADMIN_EMAIL = 'admin@trikekoto.ph';

let testEnv;

/** A phone-authenticated rider: a uid and a phone_number claim, no email. */
const rider = (uid = RIDER_UID, phone = RIDER_PHONE) =>
  testEnv
    .authenticatedContext(uid, { phone_number: phone, provider_id: 'phone' })
    .firestore();

/** An anonymous commuter — no account, which is still the default path. */
const anonCommuter = (uid = 'anon-uid-1') =>
  testEnv.authenticatedContext(uid, { provider_id: 'anonymous' }).firestore();

const driverCtx = () =>
  testEnv
    .authenticatedContext('driver-uid-1', {
      email: DRIVER_EMAIL,
      email_verified: true,
    })
    .firestore();

const adminCtx = () =>
  testEnv
    .authenticatedContext('admin-uid-1', {
      email: ADMIN_EMAIL,
      email_verified: true,
    })
    .firestore();

const anon = () => testEnv.unauthenticatedContext().firestore();

const newRider = (overrides = {}) => ({
  name: 'Maria Santos',
  phone: RIDER_PHONE,
  profilePhotoUrl: null,
  savedAddresses: [],
  ratingSum: 0,
  ratingCount: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

async function seedRider(uid = RIDER_UID, fields = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'riders', uid), {
      name: 'Maria Santos',
      phone: RIDER_PHONE,
      profilePhotoUrl: null,
      savedAddresses: [],
      ratingSum: 0,
      ratingCount: 0,
      createdAt: new Date(),
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

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ════════════════════════════════════════════════════════════
describe('creating a rider account', () => {
  it('a phone-verified rider can create their own document', async () => {
    await assertSucceeds(
      setDoc(doc(rider(), 'riders', RIDER_UID), newRider()),
    );
  });

  it('cannot create a document under someone else\'s uid', async () => {
    await assertFails(
      setDoc(doc(rider(), 'riders', OTHER_UID), newRider()),
    );
  });

  it('cannot claim a phone number the token does not carry', async () => {
    // The whole point of OTP is that the number is proven. Letting a form
    // field override it would make the verification decorative.
    await assertFails(
      setDoc(doc(rider(), 'riders', RIDER_UID),
        newRider({ phone: OTHER_PHONE })),
    );
  });

  it('an anonymous commuter cannot create one', async () => {
    // No phone_number claim at all, so there is nothing to match.
    await assertFails(
      setDoc(doc(anonCommuter('anon-uid-1'), 'riders', 'anon-uid-1'),
        newRider()),
    );
  });

  it('cannot arrive pre-rated', async () => {
    await assertFails(
      setDoc(doc(rider(), 'riders', RIDER_UID),
        newRider({ ratingSum: 25, ratingCount: 5 })),
    );
  });

  it('cannot arrive with saved addresses already populated', async () => {
    await assertFails(
      setDoc(doc(rider(), 'riders', RIDER_UID),
        newRider({ savedAddresses: [{ label: 'Bahay' }] })),
    );
  });

  it('rejects an empty name', async () => {
    await assertFails(
      setDoc(doc(rider(), 'riders', RIDER_UID), newRider({ name: '' })),
    );
  });

  it('rejects a name longer than the field allows', async () => {
    await assertFails(
      setDoc(doc(rider(), 'riders', RIDER_UID),
        newRider({ name: 'x'.repeat(61) })),
    );
  });
});

// ════════════════════════════════════════════════════════════
describe('reading a rider account', () => {
  it('a rider reads their own', async () => {
    await seedRider();
    await assertSucceeds(getDoc(doc(rider(), 'riders', RIDER_UID)));
  });

  it('another rider cannot read it', async () => {
    await seedRider();
    await assertFails(
      getDoc(doc(rider(OTHER_UID, OTHER_PHONE), 'riders', RIDER_UID)),
    );
  });

  it('a driver cannot read it', async () => {
    // A driver sees the name and number the commuter typed for that ride,
    // on the ride document. Nothing entitles them to the profile.
    await seedRider();
    await assertFails(getDoc(doc(driverCtx(), 'riders', RIDER_UID)));
  });

  it('an admin cannot read it either', async () => {
    // Deliberate. There is no operational reason to open a stranger's
    // profile, and it holds a name and a phone number.
    await seedRider();
    await assertFails(getDoc(doc(adminCtx(), 'riders', RIDER_UID)));
  });

  it('nobody unauthenticated can read it', async () => {
    await seedRider();
    await assertFails(getDoc(doc(anon(), 'riders', RIDER_UID)));
  });

  it('the collection cannot be enumerated, by anyone', async () => {
    await seedRider();
    await seedRider(OTHER_UID, { phone: OTHER_PHONE });
    for (const ctx of [rider(), driverCtx(), adminCtx(), anon()]) {
      await assertFails(getDocs(collection(ctx, 'riders')));
    }
  });
});

// ════════════════════════════════════════════════════════════
describe('editing a rider account', () => {
  it('a rider can change their name', async () => {
    await seedRider();
    await assertSucceeds(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        name: 'Maria S. Santos',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('a rider can save addresses', async () => {
    await seedRider();
    await assertSucceeds(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        savedAddresses: [{ label: 'Bahay', name: 'Poblacion', point: null }],
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('can set a profile photo URL', async () => {
    await seedRider();
    await assertSucceeds(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        profilePhotoUrl: 'https://firebasestorage.example/p.jpg',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('can clear the photo with null', async () => {
    await seedRider(RIDER_UID, { profilePhotoUrl: 'https://x.test/p.jpg' });
    await assertSucceeds(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        profilePhotoUrl: null,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('cannot park arbitrary data in the photo field', async () => {
    // An unvalidated string field is somewhere to store things that have
    // nothing to do with a photo, on someone else's bill.
    await seedRider();
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        profilePhotoUrl: 'x'.repeat(501),
      }),
    );
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), { profilePhotoUrl: 42 }),
    );
  });

  it('cannot change their phone number', async () => {
    // Proven at sign-up by OTP. Changing it means signing in again.
    await seedRider();
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), { phone: OTHER_PHONE }),
    );
  });

  it('cannot improve their own rating', async () => {
    await seedRider(RIDER_UID, { ratingSum: 8, ratingCount: 2 });
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        ratingSum: 50,
        ratingCount: 10,
      }),
    );
  });

  it('cannot blank their name', async () => {
    await seedRider();
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), { name: '' }),
    );
  });

  it('cannot hoard unbounded saved addresses', async () => {
    await seedRider();
    await assertFails(
      updateDoc(doc(rider(), 'riders', RIDER_UID), {
        savedAddresses: Array.from({ length: 21 }, (_, i) => ({
          label: `p${i}`,
        })),
      }),
    );
  });

  it('another rider cannot edit it', async () => {
    await seedRider();
    await assertFails(
      updateDoc(doc(rider(OTHER_UID, OTHER_PHONE), 'riders', RIDER_UID), {
        name: 'Hijacked',
      }),
    );
  });

  it('a rider can delete their own account', async () => {
    await seedRider();
    await assertSucceeds(deleteDoc(doc(rider(), 'riders', RIDER_UID)));
  });

  it('nobody else can delete it', async () => {
    await seedRider();
    await assertFails(
      deleteDoc(doc(rider(OTHER_UID, OTHER_PHONE), 'riders', RIDER_UID)),
    );
    await assertFails(deleteDoc(doc(adminCtx(), 'riders', RIDER_UID)));
  });
});

// ════════════════════════════════════════════════════════════
// The requirement that matters most: an account must not become a ladder.
describe('a rider account grants nothing else', () => {
  async function seedDriverDoc() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'drivers', DRIVER_EMAIL), {
        email: DRIVER_EMAIL,
        firstName: 'Juan',
        lastName: 'Dela Cruz',
        phone: '09171234567',
        plateNumber: 'ABC1234',
        todaChapter: 'Barangay Uno TODA',
        status: 'approved',
        ratingSum: 0,
        ratingCount: 0,
      });
      await setDoc(doc(ctx.firestore(), 'admins', ADMIN_EMAIL), {
        email: ADMIN_EMAIL,
        displayName: 'Ops',
        createdAt: new Date(),
      });
    });
  }

  it('cannot read a driver profile', async () => {
    await seedRider();
    await seedDriverDoc();
    await assertFails(getDoc(doc(rider(), 'drivers', DRIVER_EMAIL)));
  });

  it('cannot list drivers', async () => {
    await seedRider();
    await seedDriverDoc();
    await assertFails(getDocs(collection(rider(), 'drivers')));
  });

  it('cannot write to a driver profile', async () => {
    await seedRider();
    await seedDriverDoc();
    await assertFails(
      updateDoc(doc(rider(), 'drivers', DRIVER_EMAIL), { status: 'suspended' }),
    );
  });

  it('cannot read the admin list', async () => {
    await seedRider();
    await seedDriverDoc();
    await assertFails(getDoc(doc(rider(), 'admins', ADMIN_EMAIL)));
  });

  it('cannot mint themselves an admin entry', async () => {
    await seedRider();
    await assertFails(
      setDoc(doc(rider(), 'admins', 'rider@evil.ph'), {
        email: 'rider@evil.ph',
        displayName: 'Me',
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('cannot change dispatch or fare configuration', async () => {
    await seedRider();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config', 'app'), {
        searchRadiusKm: 5,
      });
    });
    await assertFails(
      updateDoc(doc(rider(), 'config', 'app'), { searchRadiusKm: 500 }),
    );
  });
});
