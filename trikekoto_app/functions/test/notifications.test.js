// Unit tests for the in-app notices in src/notifications.ts.
// Run: npm test   (compiles, then runs these against lib/)
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  justApproved,
  ACCOUNT_APPROVED,
  NOTICE_ACCOUNT_APPROVED,
} = require('../lib/notifications.js');

const driver = (status, rest = {}) => ({ status, uid: 'uid-1', ...rest });

test('approving a pending driver is news', () => {
  assert.equal(justApproved(driver('pending'), driver('approved')), true);
});

test('a profile rewritten while already approved is not', () => {
  // Every rating and every edit rewrites the document. A driver told again
  // each time would learn to ignore the notice that matters.
  assert.equal(justApproved(driver('approved'), driver('approved')), false);
});

test('a rejection or a suspension says nothing', () => {
  assert.equal(justApproved(driver('pending'), driver('rejected')), false);
  assert.equal(justApproved(driver('approved'), driver('suspended')), false);
});

test('being approved again after a suspension is news again', () => {
  assert.equal(justApproved(driver('suspended'), driver('approved')), true);
});

test('a first write, with nothing before it, still counts', () => {
  // A profile created as approved — an admin adding a driver directly — has
  // no "before" to compare against.
  assert.equal(justApproved(undefined, driver('approved')), true);
});

test('a deleted profile is not an approval', () => {
  assert.equal(justApproved(driver('pending'), undefined), false);
});

test('the notice says what the specification says', () => {
  assert.equal(ACCOUNT_APPROVED.type, NOTICE_ACCOUNT_APPROVED);
  assert.equal(
    ACCOUNT_APPROVED.body,
    'Your account has been approved by the admin. You can now log in.',
  );
});
