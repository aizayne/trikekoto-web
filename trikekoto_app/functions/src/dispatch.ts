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
export type PresenceRow = { email: string; position?: { geopoint?: LatLng } };

/** A ride, as much of it as knowing who holds an offer reads. */
export type RideOfferState = {
  id: string;
  status?: string;
  dispatch?: {
    offeredTo?: string | null;
    offerExpiresAt?: { toDate(): Date } | null;
  };
};

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
 * Drivers who may be offered this ride, nearest first by straight line.
 *
 * Leaves out anyone already tried for this ride, anyone currently holding a
 * live offer for another ride, anyone without a position, and anyone beyond
 * the radius. Ties break on email so the same inputs always give the same
 * order — a dispatch that picks differently on a retry is impossible to
 * reason about from a log.
 */
export function shortlistByDistance(
  rows: readonly PresenceRow[],
  pickup: LatLng,
  opts: {
    attempted: readonly string[];
    busy: ReadonlySet<string>;
    radiusKm: number;
  },
): Candidate[] {
  return rows
    .filter((r) => !opts.attempted.includes(r.email) && !opts.busy.has(r.email))
    .flatMap((r) => {
      const point = r.position?.geopoint;
      if (!point) return [];
      const km = haversineKm(pickup, point);
      return km <= opts.radiusKm ? [{ email: r.email, point, km }] : [];
    })
    .sort((a, b) => a.km - b.km || a.email.localeCompare(b.email));
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
 * Drivers holding an unexpired offer on some other searching ride.
 *
 * Without this, two commuters booking near the same terminal were both
 * offered the one nearest driver, and whichever ride they did not take lost
 * a full timeout waiting on someone who was never going to answer it.
 */
export function driversHoldingOffers(
  rides: readonly RideOfferState[],
  now: Date,
  exceptRideId?: string,
): Set<string> {
  const busy = new Set<string>();
  for (const r of rides) {
    if (r.id === exceptRideId || r.status !== 'searching') continue;
    const to = r.dispatch?.offeredTo;
    const expires = r.dispatch?.offerExpiresAt?.toDate();
    if (to && expires && expires > now) busy.add(to);
  }
  return busy;
}

/**
 * How long to wait before checking whether an offer lapsed: one second past
 * its expiry, so the check never lands a moment early; never negative; and
 * capped, so a bad timestamp cannot hold a function open until it times out.
 */
export function msUntilLapsed(expiresAt: Date, now: Date, capMs = 150_000): number {
  return Math.min(Math.max(expiresAt.getTime() - now.getTime() + 1000, 0), capMs);
}
