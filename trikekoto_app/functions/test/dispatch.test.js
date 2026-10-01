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
  isAbandoned,
  canShare,
  detourKm,
  SHARING_FALLBACK,
  needsNoDriverNotice,
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
    { exceptRideId: 'r4' },
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

test('a driver who went quiet is passed over while anyone else is checking in', () => {
  const list = shortlistByDistance(
    [checkingIn('ghost', 0.5, 900), checkingIn('live', 1, 30), row('old-app', 2)],
    pickup,
    opts({ now: NOW }),
  );
  // 'ghost' is nearer than both and still not offered: a driver who is not
  // checking in is a worse bet than one who is.
  assert.deepEqual(emails(list), ['live', 'old-app']);
});

test('but is asked when nobody else is available', () => {
  // The terminal is a dead spot. Dropping these drivers outright made
  // dispatch a test of signal strength, and told commuters no driver exists
  // while three sat at the kerb.
  const list = shortlistByDistance(
    [checkingIn('ghost', 0.5, 900), checkingIn('quiet', 2, 600)],
    pickup,
    opts({ now: NOW }),
  );
  assert.deepEqual(emails(list), ['ghost', 'quiet']);
});

test('and is dropped once the silence is long enough to mean gone', () => {
  assert.equal(isAbandoned(checkingIn('a', 1, 29 * 60), NOW), false);
  assert.equal(isAbandoned(checkingIn('a', 1, 31 * 60), NOW), true);
  const list = shortlistByDistance(
    [checkingIn('gone', 0.5, 40 * 60), checkingIn('quiet', 2, 600)],
    pickup,
    opts({ now: NOW }),
  );
  assert.deepEqual(emails(list), ['quiet']);
});

test('an app too old to check in is never dropped for silence', () => {
  // It only writes when it moves, so a parked driver on one looks exactly
  // like a phone switched off.
  assert.equal(isAbandoned({ ...row('old', 1), updatedAt: ago(86400) }, NOW), false);
});


// ── Shared rides ────────────────────────────────────────────
// San Marcelino plaza is `pickup`. These sit on a line north of it, so a
// passenger going the same way adds almost nothing and one going back adds
// twice the distance.
const upRoad = (km) => ({ latitude: pickup.latitude + km / 111.2, longitude: pickup.longitude });
const trip = (id, fromKm, toKm, extra = {}) => ({
  id,
  status: 'in_transit',
  assignedDriver: 'juan',
  serviceType: 'regular',
  pickup: { geopoint: at(fromKm) },
  dropoff: { geopoint: at(toKm) },
  ...extra,
});

test('a driver with nobody aboard is always free', () => {
  assert.equal(canShare([], trip('new', 0, 3), upRoad(0)), true);
});

test('a passenger going the same way rides along', () => {
  // Driver is at 1 km heading to 4 km; the new trip runs 1.2 km to 3.5 km.
  const current = trip('aboard', 0, 4);
  const candidate = trip('next', 1.2, 3.5);
  assert.ok(detourKm(upRoad(1), current, candidate) < 1);
  assert.equal(canShare([current], candidate, upRoad(1)), true);
});

test('a passenger going the other way does not', () => {
  const current = trip('aboard', 0, 4);
  const candidate = trip('next', -2, -3);
  assert.equal(canShare([current], candidate, upRoad(1)), false);
});

test('a special trip is the whole tricycle, in both directions', () => {
  const regular = trip('aboard', 0, 4);
  const special = trip('next', 1.2, 3.5, { serviceType: 'special' });
  // Nobody joins a special trip, and a special trip joins nobody.
  assert.equal(canShare([regular], special, upRoad(1)), false);
  assert.equal(
    canShare([trip('aboard', 0, 4, { serviceType: 'special' })], trip('next', 1.2, 3.5), upRoad(1)),
    false,
  );
});

test('the tricycle fills up', () => {
  const aboard = [trip('a', 0, 4), trip('b', 0.5, 4), trip('c', 0.6, 4)];
  assert.equal(canShare(aboard, trip('d', 1.2, 3.5), upRoad(1)), false, 'three is the default cap');
  assert.equal(
    canShare(aboard.slice(0, 2), trip('d', 1.2, 3.5), upRoad(1)),
    true,
    'two still has room',
  );
});

test('every passenger aboard has to still be on the way, not the average', () => {
  // One going north, one going south: a candidate that suits one takes the
  // other a long way round.
  const north = trip('north', 0, 4);
  const south = trip('south', 0, -4);
  assert.equal(canShare([north, south], trip('next', 1.2, 3.5), upRoad(1)), false);
});

test('a ride with no coordinates is never shared', () => {
  // Rides from the old web build carry labels and no points. A detour that
  // cannot be measured must not be assumed small.
  const legacy = { id: 'old', status: 'accepted', assignedDriver: 'juan', dropoff: {} };
  assert.equal(detourKm(upRoad(1), legacy, trip('next', 1.2, 3.5)), null);
  assert.equal(canShare([legacy], trip('next', 1.2, 3.5), upRoad(1)), false);
  assert.equal(canShare([trip('aboard', 0, 4)], { id: 'n', pickup: {}, dropoff: {} }, upRoad(1)), false);
});

test('and neither is one whose driver has not said where they are', () => {
  assert.equal(canShare([trip('aboard', 0, 4)], trip('next', 1.2, 3.5), undefined), false);
});

test('sharing can be switched off for a chapter', () => {
  const off = { ...SHARING_FALLBACK, enabled: false };
  assert.equal(canShare([trip('aboard', 0, 4)], trip('next', 1.2, 3.5), upRoad(1), off), false);
  assert.equal(canShare([], trip('next', 1.2, 3.5), upRoad(1), off), true, 'an empty trike is still free');
});

test('dispatch offers a sharing driver the ride that suits them', () => {
  const rides = [trip('aboard', 0, 4)];
  const sameWay = unavailableDrivers(rides, NOW_OFFERS, {
    candidate: trip('next', 1.2, 3.5),
    at: new Map([['juan', upRoad(1)]]),
  });
  assert.deepEqual([...sameWay], [], 'free for a trip going their way');

  const otherWay = unavailableDrivers(rides, NOW_OFFERS, {
    candidate: trip('next', -2, -3),
    at: new Map([['juan', upRoad(1)]]),
  });
  assert.deepEqual([...otherWay], ['juan'], 'busy for one that is not');
});

test('and keeps them busy when no candidate is named', () => {
  // The sweep asking in general, before it knows which ride it is placing.
  const busy = unavailableDrivers([trip('aboard', 0, 4)], NOW_OFFERS);
  assert.deepEqual([...busy], ['juan']);
});

// ── Telling the commuter nobody has accepted ────────────────
const created = (secondsAgo, sent) => ({
  createdAt: { toDate: () => new Date(NOW.getTime() - secondsAgo * 1000) },
  noDriverNoticeSent: sent,
});

test('the commuter is told once, after three minutes of nobody accepting', () => {
  assert.equal(needsNoDriverNotice(created(179), NOW), false);
  assert.equal(needsNoDriverNotice(created(181), NOW), true);
});

test('a commuter already told is not told again', () => {
  assert.equal(needsNoDriverNotice(created(600, true), NOW), false);
});

test('a ride with no creation time is never judged late', () => {
  assert.equal(needsNoDriverNotice({}, NOW), false);
});
