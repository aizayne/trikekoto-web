// Unit tests for driver removal in src/removal.ts.
// Run: npm test   (compiles, then runs these against lib/)
const test = require('node:test');
const assert = require('node:assert/strict');
const { actionForRide, shouldDeleteAccount } = require('../lib/removal.js');

const EMAIL = 'juan@toda.ph';

test('a passenger already aboard means the ride is called off', () => {
  assert.equal(
    actionForRide({ id: 'r1', status: 'in_transit', assignedDriver: EMAIL }, EMAIL),
    'cancel',
  );
  assert.equal(
    actionForRide({ id: 'r2', status: 'accepted', assignedDriver: EMAIL }, EMAIL),
    'cancel',
  );
});

test('an offer open at that second is released, not cancelled', () => {
  // Clearing it is what a decline does; dispatch moves to the next driver
  // rather than the commuter losing a booking nobody had accepted.
  assert.equal(
    actionForRide(
      { id: 'r3', status: 'searching', dispatch: { offeredTo: EMAIL } },
      EMAIL,
    ),
    'release',
  );
});

test('a finished ride is kept, with the contact detail scrubbed', () => {
  assert.equal(
    actionForRide({ id: 'r4', status: 'completed', assignedDriver: EMAIL }, EMAIL),
    'scrub',
  );
  assert.equal(
    actionForRide({ id: 'r5', status: 'cancelled', assignedDriver: EMAIL }, EMAIL),
    'scrub',
  );
});

test("another driver's live ride is never touched", () => {
  // Emails are the key everywhere in this schema, so a near-miss must not
  // cancel a ride that belongs to somebody else.
  assert.equal(
    actionForRide(
      { id: 'r6', status: 'in_transit', assignedDriver: 'pedro@toda.ph' },
      EMAIL,
    ),
    'scrub',
  );
  assert.equal(
    actionForRide(
      { id: 'r7', status: 'searching', dispatch: { offeredTo: 'pedro@toda.ph' } },
      EMAIL,
    ),
    'scrub',
  );
});

test('a mixed-case address still matches its own ride', () => {
  assert.equal(
    actionForRide({ id: 'r8', status: 'accepted', assignedDriver: 'Juan@Toda.ph' }, EMAIL),
    'cancel',
  );
});

test('the sign-in account goes with the profile', () => {
  assert.equal(shouldDeleteAccount({ uid: 'uid-1', isAdmin: false }), true);
});

test('unless the same address is an admin, or there is no account', () => {
  // Deleting the login of the officer doing the removing would lock the
  // chapter out of its own panel.
  assert.equal(shouldDeleteAccount({ uid: 'uid-1', isAdmin: true }), false);
  assert.equal(shouldDeleteAccount({ uid: null, isAdmin: false }), false);
});
