const test = require('node:test');
const assert = require('node:assert/strict');
const {
  deviceSecretMatches,
  hashDeviceSecret,
  newDeviceSecret,
} = require('../lib/device_login');

test('a secret is 256 bits and never repeats', () => {
  const a = newDeviceSecret();
  assert.equal(a.length, 64);
  assert.notEqual(a, newDeviceSecret());
});

test('the right secret matches its hash', () => {
  const secret = newDeviceSecret();
  assert.equal(deviceSecretMatches(secret, hashDeviceSecret(secret)), true);
});

test('another phone\'s secret does not', () => {
  assert.equal(
    deviceSecretMatches(newDeviceSecret(), hashDeviceSecret(newDeviceSecret())),
    false,
  );
});

test('the stored hash cannot be used as the secret', () => {
  const hash = hashDeviceSecret(newDeviceSecret());
  assert.equal(deviceSecretMatches(hash, hash), false);
});

test('a missing or malformed hash is a refusal, not a crash', () => {
  for (const stored of [undefined, null, 42, '', 'short']) {
    assert.equal(deviceSecretMatches('anything', stored), false);
  }
});
