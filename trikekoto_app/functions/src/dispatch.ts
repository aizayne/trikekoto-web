/**
 * The ranking half of dispatch, with no Firebase in it, so it can be tested.
 *
 * Greedy nearest-first, in two stages: straight-line distance applies the
 * radius and orders the field; road distance over a short list decides the
 * winner. Everything that needs the database — who is approved, who is
 * online, writing the offer — stays in index.ts.
 */

export type LatLng = { latitude: number; longitude: number };

export type Candidate = { email: string; point: LatLng; km: number };

/** A row of `active_drivers`, as much of it as ranking reads. */
export type PresenceRow = {
  email: string;
  position?: { geopoint?: LatLng };
  /** How often this driver's app promised to check in. Absent on old apps. */
  heartbeatSeconds?: number;
  updatedAt?: { toDate(): Date } | null;
};

/** Missed check-ins after which a driver is treated as gone. */
export const MISSED_HEARTBEATS = 2.5;

/**
 * True when a driver's app has stopped checking in — closed, killed or out of
 * signal — while its presence still says online.
 *
 * Only a row carrying `heartbeatSeconds` can be stale. An app older than the
 * check-in writes only when it moves, so a parked driver on one looks exactly
 * like a gone one; judging them by silence would cut off every driver waiting
 * at the terminal until they update.
 */
export function isStale(row: PresenceRow, now: Date): boolean {
  const every = row.heartbeatSeconds;
  const at = row.updatedAt?.toDate();
  if (!every || every <= 0 || !at) return false;
  return now.getTime() - at.getTime() > every * MISSED_HEARTBEATS * 1000;
}

/** A ride, as much of it as knowing who is unavailable reads. */
export type RideOfferState = {
  id: string;
  status?: string;
  assignedDriver?: string | null;
  /** `regular` or `special`. Absent on rides booked before trip types. */
  serviceType?: string;
  pickup?: { geopoint?: LatLng | null };
  dropoff?: { geopoint?: LatLng | null };
  dispatch?: {
    offeredTo?: string | null;
    offerExpiresAt?: { toDate(): Date } | null;
  };
};

/** How a chapter wants its tricycles shared. */
export type SharingConfig = {
  enabled: boolean;
  /** Passengers one tricycle may carry at once, the first one included. */
  maxPassengers: number;
  /** How far out of its way a trike may go for the next passenger. */
  maxDetourKm: number;
};

export const SHARING_FALLBACK: SharingConfig = {
  enabled: true,
  maxPassengers: 3,
  maxDetourKm: 1.5,
};

/** A ride a driver is already carrying. */
function isUnderway(r: RideOfferState): boolean {
  return r.status === 'accepted' || r.status === 'in_transit';
}

function isSpecial(r: RideOfferState | undefined): boolean {
  return r?.serviceType === 'special';
}

/**
 * How much further a driver travels to take [candidate] on the way.
 *
 * Measured against the trip they are already on: go to the new pickup, carry
 * that passenger to their drop-off, then continue to the one already aboard —
 * minus what the original trip would have cost from here. A passenger going
 * the same way adds almost nothing; one going the opposite way adds twice the
 * distance, which is the number this exists to catch.
 *
 * Null when any end is missing coordinates. Rides from the old web build have
 * labels and no points, and a detour that cannot be measured must not be
 * assumed small.
 */
export function detourKm(
  from: LatLng,
  current: RideOfferState,
  candidate: RideOfferState,
): number | null {
  const theirDrop = current.dropoff?.geopoint;
  const pick = candidate.pickup?.geopoint;
  const drop = candidate.dropoff?.geopoint;
  if (!theirDrop || !pick || !drop) return null;

  const direct = haversineKm(from, theirDrop);
  const shared =
    haversineKm(from, pick) + haversineKm(pick, drop) + haversineKm(drop, theirDrop);
  return shared - direct;
}

/**
 * Whether a driver already carrying [current] may be offered [candidate].
 *
 * Four refusals, in the order a driver would give them:
 *
 * - **A special trip is the whole tricycle.** The passenger paid five fares
 *   for exactly that, so a special ride neither shares nor joins.
 * - **The tricycle fills up.** Three passengers by default; a TODA tricycle
 *   seats more, but a driver juggling four drop-offs from a phone is how
 *   somebody gets taken past their street.
 * - **The new trip has to be on the way.** Beyond the detour budget it is not
 *   sharing, it is a second trip the first passenger pays for in time.
 * - **Unmeasurable is unshareable.** A ride with no coordinates cannot be
 *   checked, so it is not offered as a share.
 */
export function canShare(
  current: readonly RideOfferState[],
  candidate: RideOfferState,
  at: LatLng | undefined,
  config: SharingConfig = SHARING_FALLBACK,
): boolean {
  if (!config.enabled || current.length === 0) return current.length === 0;
  if (isSpecial(candidate) || current.some(isSpecial)) return false;
  if (current.length >= config.maxPassengers) return false;
  if (!at) return false;

  // Against every passenger already aboard: the one who would be taken
  // furthest out of their way decides it, not the average.
  for (const ride of current) {
    const extra = detourKm(at, ride, candidate);
    if (extra === null || extra > config.maxDetourKm) return false;
  }
  return true;
}

/** Great-circle distance in kilometres — the same measure the client sorts by. */
export function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) *
      Math.cos(toRad(b.latitude)) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/**
 * How long a driver's app can be silent before it is treated as gone rather
 * than as out of signal.
 *
 * Far longer than the staleness window on purpose. Silence means one of two
 * very different things — the app was closed, or the phone is in a dead spot
 * — and from the server they look identical for the first few minutes. Half
 * an hour is long enough that a driver riding through a weak patch is still
 * in the running, and short enough that a phone switched off at the end of a
 * shift stops taking offer slots.
 */
export const ABANDONED_AFTER_MINUTES = 30;

export function isAbandoned(row: PresenceRow, now: Date): boolean {
  const every = row.heartbeatSeconds;
  const at = row.updatedAt?.toDate();
  if (!every || every <= 0 || !at) return false;
  return now.getTime() - at.getTime() > ABANDONED_AFTER_MINUTES * 60_000;
}

/**
 * Drivers who may be offered this ride, nearest first by straight line.
 *
 * Leaves out anyone already tried for this ride, anyone currently holding a
 * live offer for another ride, anyone without a position, and anyone beyond
 * the radius. Ties break on email so the same inputs always give the same
 * order — a dispatch that picks differently on a retry is impossible to
 * reason about from a log.
 *
 * **A weak signal costs a driver their place in the queue, not the queue.**
 * Checking in late used to remove a driver outright, which made dispatch a
 * test of signal strength: the terminal sits in a dead spot, so the drivers
 * parked at it — the ones nearest almost every pickup — were the ones being
 * skipped. Now a driver who has missed check-ins is simply ranked behind
 * everyone who has not, and is asked only when nobody fresh is available.
 * Being hard to reach makes a driver a worse bet than a driver who is not;
 * it does not make them unavailable, and the commuter would rather wait 15
 * seconds for a maybe than be told no driver exists.
 *
 * Only true silence — [ABANDONED_AFTER_MINUTES] — removes anyone.
 */
export function shortlistByDistance(
  rows: readonly PresenceRow[],
  pickup: LatLng,
  opts: {
    attempted: readonly string[];
    busy: ReadonlySet<string>;
    radiusKm: number;
    /** When set, drivers who have gone quiet are ranked last, then dropped. */
    now?: Date;
  },
): Candidate[] {
  const within = (rows: readonly PresenceRow[]): Candidate[] =>
    rows
      .flatMap((r) => {
        const point = r.position?.geopoint;
        if (!point) return [];
        const km = haversineKm(pickup, point);
        return km <= opts.radiusKm ? [{ email: r.email, point, km }] : [];
      })
      .sort((a, b) => a.km - b.km || a.email.localeCompare(b.email));

  const eligible = rows
    .filter((r) => !opts.attempted.includes(r.email) && !opts.busy.has(r.email))
    .filter((r) => !opts.now || !isAbandoned(r, opts.now));

  if (!opts.now) return within(eligible);

  // Two tiers, never mixed: road ranking happens inside whichever tier is
  // offered, so a driver who went quiet can never be chosen over one who is
  // checking in from the same street.
  const fresh = eligible.filter((r) => !isStale(r, opts.now!));
  return within(fresh.length > 0 ? fresh : eligible);
}

/**
 * The winner, by road distance where routing answered.
 *
 * [roadKm] lines up with [candidates]. A null entry means no road connection
 * to the pickup: that driver is dropped rather than ranked last, because an
 * offer they cannot act on burns a whole timeout. If routing failed outright
 * — or dropped everyone — the straight-line order stands: a routing outage
 * may degrade the choice but must never stop a ride being offered.
 */
export function pickByRoad(
  candidates: readonly Candidate[],
  roadKm: readonly (number | null)[] | null,
): Candidate | null {
  if (candidates.length === 0) return null;
  if (!roadKm || roadKm.length !== candidates.length) return candidates[0];

  const routed = candidates
    .map((c, i) => ({ c, road: roadKm[i] }))
    .filter((x): x is { c: Candidate; road: number } => x.road !== null)
    .sort((a, b) => a.road - b.road || a.c.km - b.c.km);

  return routed.length > 0 ? routed[0].c : candidates[0];
}

/**
 * Drivers who must not be offered a ride right now: those already carrying a
 * passenger, and those holding an unexpired offer on another searching ride.
 *
 * Read from the rides themselves rather than from `active_drivers.availability`,
 * which is written by the driver's phone and only refreshed when it pings —
 * on movement, or at the check-in interval. Between accepting a ride and the
 * next ping, that flag still said `idle`, so a second booking was offered to a
 * driver who already had a passenger; their app hides new offers during a
 * ride, so the offer sat unanswered for its whole timeout. The mirror case was
 * worse in the other direction: for a while after dropping someone off, the
 * flag still said `on_ride` and the nearest free driver was passed over.
 *
 * A ride document changes the instant a driver accepts or completes, so it
 * cannot lag.
 */
export function unavailableDrivers(
  rides: readonly RideOfferState[],
  now: Date,
  opts: {
    exceptRideId?: string;
    /** The ride being dispatched, when sharing is to be considered. */
    candidate?: RideOfferState;
    /** Where each driver last reported being, for the detour check. */
    at?: ReadonlyMap<string, LatLng>;
    sharing?: SharingConfig;
  } = {},
): Set<string> {
  const busy = new Set<string>();
  const carrying = new Map<string, RideOfferState[]>();

  for (const r of rides) {
    if (isUnderway(r)) {
      if (!r.assignedDriver) continue;
      const list = carrying.get(r.assignedDriver) ?? [];
      list.push(r);
      carrying.set(r.assignedDriver, list);
      continue;
    }
    if (r.id === opts.exceptRideId || r.status !== 'searching') continue;
    const to = r.dispatch?.offeredTo;
    const expires = r.dispatch?.offerExpiresAt?.toDate();
    if (to && expires && expires > now) busy.add(to);
  }

  // A driver with a passenger is unavailable unless this particular ride can
  // ride along. Without a candidate — the sweep asking in general — they are
  // simply unavailable, which is the old behaviour and the safe one.
  for (const [driver, rides] of carrying) {
    const shareable =
      opts.candidate !== undefined &&
      canShare(rides, opts.candidate, opts.at?.get(driver), opts.sharing);
    if (!shareable) busy.add(driver);
  }
  return busy;
}

/**
 * How long a commuter waits before being told nobody has accepted.
 *
 * Mirrors `noDriverAfter` in commuter_booking_screen.dart: the app shows a
 * dialog at three minutes, and this sends the push for the app that is closed
 * or in a pocket. Both leave the search running for the remaining minutes.
 */
export const NO_DRIVER_NOTICE_MINUTES = 3;

/**
 * Whether this ride has waited long enough to say so, and has not been told
 * already. Sent once per booking: a second "still nobody" is noise.
 */
export function needsNoDriverNotice(
  ride: { createdAt?: { toDate(): Date }; noDriverNoticeSent?: boolean },
  now: Date,
  minutes: number = NO_DRIVER_NOTICE_MINUTES,
): boolean {
  if (ride.noDriverNoticeSent) return false;
  const created = ride.createdAt?.toDate();
  if (!created) return false;
  return now.getTime() - created.getTime() >= minutes * 60_000;
}

/**
 * How long to wait before checking whether an offer lapsed: one second past
 * its expiry, so the check never lands a moment early; never negative; and
 * capped, so a bad timestamp cannot hold a function open until it times out.
 */
export function msUntilLapsed(expiresAt: Date, now: Date, capMs = 150_000): number {
  return Math.min(Math.max(expiresAt.getTime() - now.getTime() + 1000, 0), capMs);
}
