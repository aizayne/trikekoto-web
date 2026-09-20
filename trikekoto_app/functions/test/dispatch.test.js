// Unit tests for the dispatch ranking in src/dispatch.ts.
// Run: npm test   (compiles, then runs these against lib/)
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  haversineKm,
  shortlistByDistance,
  pickByRoad,
  unavailableDrivers,
  msUntilLapsed,
  isStale,
} = require('../lib/dispatch.js');

// San Marcelino plaza. One degree of latitude is about 111.2 km.
const pickup = { latitude: 14.9747, longitude: 120.1577 };
const at = (km) => ({ latitude: pickup.latitude + km / 111.2, longitude: pickup.longitude });
const row = (email, km) => ({ email, position: { geopoint: at(km) } });
const opts = (o = {}) => ({ attempted: [], busy: new Set(), radiusKm: 5, ...o });
const emails = (list) => list.map((c) => c.email);

test('haversine agrees with a known distance', () => {
  assert.ok(Math.abs(haversineKm(pickup, at(3)) - 3) < 0.01);
});

test('nearest first, and only inside the radius', () => {
  const list = shortlistByDistance([row('far', 4), row('near', 1), row('out', 6)], pickup, opts());
  assert.deepEqual(emails(list), ['near', 'far']);
});

test('skips drivers already tried for this ride', () => {
  const list = shortlistByDistance([row('a', 1), row('b', 2)], pickup, opts({ attempted: ['a'] }));
  assert.deepEqual(emails(list), ['b']);
});

test('skips a driver holding a live offer for another ride', () => {
  const list = shortlistByDistance([row('a', 1), row('b', 2)], pickup, opts({ busy: new Set(['a']) }));
  assert.deepEqual(emails(list), ['b']);
});

test('a driver with no position is never offered', () => {
  const list = shortlistByDistance([{ email: 'ghost' }, row('b', 2)], pickup, opts());
  assert.deepEqual(emails(list), ['b']);
});

test('ties break the same way every time', () => {
  const list = shortlistByDistance([row('b', 1), row('a', 1)], pickup, opts());
  assert.deepEqual(emails(list), ['a', 'b']);
});

test('road distance overrides straight-line distance', () => {
  const list = shortlistByDistance([row('near', 1), row('far', 2)], pickup, opts());
  // The nearer driver is across the river: 5 km by road against 2.
  assert.equal(pickByRoad(list, [5, 2]).email, 'far');
});

test('a driver with no road to the pickup is dropped, not ranked last', () => {
  const list = shortlistByDistance([row('island', 1), row('mainland', 3)], pickup, opts());
  assert.equal(pickByRoad(list, [null, 3.5]).email, 'mainland');
});

test('when routing fails, straight-line order stands', () => {
  const list = shortlistByDistance([row('near', 1), row('far', 2)], pickup, opts());
  assert.equal(pickByRoad(list, null).email, 'near');
  assert.equal(pickByRoad(list, [2]).email, 'near', 'a malformed reply is ignored');
  assert.equal(pickByRoad(list, [null, null]).email, 'near', 'routing dropping everyone never stops an offer');
});

test('no candidates, no pick', () => {
  assert.equal(pickByRoad([], null), null);
});

const NOW_OFFERS = new Date('2026-09-17T08:00:00Z');
const later = { toDate: () => new Date('2026-09-17T08:00:10Z') };
const earlier = { toDate: () => new Date('2026-09-17T07:59:50Z') };

test('only live offers on other searching rides make a driver busy', () => {
  const busy = unavailableDrivers(
    [
      { id: 'r1', status: 'searching', dispatch: { offeredTo: 'live', offerExpiresAt: later } },
      { id: 'r2', status: 'searching', dispatch: { offeredTo: 'lapsed', offerExpiresAt: earlier } },
      { id: 'r4', status: 'searching', dispatch: { offeredTo: 'self', offerExpiresAt: later } },
      { id: 'r5', status: 'searching', dispatch: { offeredTo: null, offerExpiresAt: null } },
    ],
    NOW_OFFERS,
    'r4',
  );
  assert.deepEqual([...busy], ['live']);
});

test('a driver carrying a passenger is busy, whatever their phone last said', () => {
  // The bug this closes: between accepting and the next ping, presence still
  // read `idle`, so the next booking went to a driver who already had someone
  // aboard — and their app hides offers during a ride, so it went unanswered.
  const busy = unavailableDrivers(
    [
      { id: 'r1', status: 'accepted', assignedDriver: 'carrying' },
      { id: 'r2', status: 'in_transit', assignedDriver: 'driving' },
    ],
    NOW_OFFERS,
  );
  assert.deepEqual([...busy].sort(), ['carrying', 'driving']);
});

test('a finished ride frees its driver at once', () => {
  const busy = unavailableDrivers(
    [
      { id: 'r1', status: 'completed', assignedDriver: 'free' },
      { id: 'r2', status: 'cancelled', assignedDriver: 'also-free' },
      { id: 'r3', status: 'expired', assignedDriver: null },
    ],
    NOW_OFFERS,
  );
  assert.equal(busy.size, 0);
});

test('the lapse check waits one second past expiry, never less than zero, capped', () => {
  const now = new Date('2026-09-17T08:00:00Z');
  assert.equal(msUntilLapsed(new Date('2026-09-17T08:00:15Z'), now), 16_000);
  assert.equal(msUntilLapsed(new Date('2026-09-17T07:59:00Z'), now), 0);
  assert.equal(msUntilLapsed(new Date('2026-09-17T09:00:00Z'), now), 150_000);
});

// ── Check-ins ───────────────────────────────────────────────
const NOW = new Date('2026-09-18T08:00:00Z');
const ago = (s) => ({ toDate: () => new Date(NOW.getTime() - s * 1000) });
const checkingIn = (email, km, secondsAgo) => ({ ...row(email, km), heartbeatSeconds: 120, updatedAt: ago(secondsAgo) });

test('a driver who keeps checking in is not stale, however long parked', () => {
  assert.equal(isStale(checkingIn('a', 1, 110), NOW), false);
  assert.equal(isStale(checkingIn('a', 1, 299), NOW), false, 'within two and a half check-ins');
});

test('a driver who stopped checking in is stale', () => {
  assert.equal(isStale(checkingIn('a', 1, 301), NOW), true);
});

test('an app too old to promise check-ins is never judged by silence', () => {
  assert.equal(isStale({ ...row('old', 1), updatedAt: ago(86400) }, NOW), false);
});

test('dispatch skips a driver whose app went quiet', () => {
  const list = shortlistByDistance(
    [checkingIn('ghost', 0.5, 900), checkingIn('live', 1, 30), row('old-app', 2)],
    pickup,
    opts({ now: NOW }),
  );
  assert.deepEqual(emails(list), ['live', 'old-app']);
});
