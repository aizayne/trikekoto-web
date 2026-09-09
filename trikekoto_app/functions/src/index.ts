/**
 * TrikeKoTo Cloud Functions
 * =========================
 *
 * Three jobs the client genuinely cannot do:
 *
 *  1. **Send push notifications.** FCM sending needs a server credential.
 *     Embedding one in an APK that is handed around by QR code would let
 *     anyone push to any driver, so this is not a preference — it is the
 *     only safe place for it.
 *
 *  2. **Keep dispatch alive.** The greedy sweep runs on the commuter's
 *     handset. If they lock the screen mid-search, the ride sits in
 *     `searching` forever and no driver is ever pinged.
 *
 *  3. **Expire stale offers.** An offer that lapses while nobody has the app
 *     open blocks the ride from being re-offered.
 *
 *  4. **Enforce retention on government IDs.** A deletion policy a human
 *     performs by hand is a policy that will be forgotten, and the data it
 *     governs is the most sensitive the system holds.
 */

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, GeoPoint, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';
import { onDocumentDeleted, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';

initializeApp();
const db = getFirestore();

const REGION = 'asia-southeast1';

/** Mirrors DispatchDefaults in the Flutter client. */
/**
 * How long a ride may sit unmatched before the system gives up on it.
 *
 * The candidate budget alone is not enough. Both sweeps skip a ride when no
 * driver is available, deliberately — someone may come online — but they skip
 * it *without* spending a candidate. So a ride booked when the chapter is
 * asleep never reaches the budget and never expires: the commuter watches a
 * spinner indefinitely, with nothing on screen admitting that nobody is
 * coming.
 *
 * Five minutes is long enough for a driver starting a shift to still pick it
 * up, and short enough that nobody stares at a spinner wondering.
 */
const SEARCH_TIMEOUT_MINUTES = 5;

const FALLBACK = {
  searchRadiusKm: 5,
  offerTimeoutSeconds: 15,
  maxDriversToTry: 10,
  routingBaseUrl: 'https://router.project-osrm.org',
};

/** Mirrors DispatchDefaults.roadRankLimit in the Flutter client. */
const ROAD_RANK_LIMIT = 8;

type RideDispatch = {
  offeredTo?: string | null;
  offerSeq?: number;
  offerExpiresAt?: FirebaseFirestore.Timestamp | null;
  attemptedDrivers?: string[];
  depth?: number;
};

type Ride = {
  status?: string;
  commuterUid?: string | null;
  createdAt?: FirebaseFirestore.Timestamp;
  rating?: number | null;
  ratingCounted?: boolean;
  commuterName?: string;
  commuterFcmToken?: string | null;
  pickup?: { label?: string; geopoint?: GeoPoint };
  dropoff?: { label?: string };
  dispatch?: RideDispatch;
  assignedDriver?: string | null;
  driverSnapshot?: { firstName?: string; plateNumber?: string } | null;
};

async function readConfig() {
  try {
    const snap = await db.doc('config/app').get();
    const d = snap.data() ?? {};
    return {
      searchRadiusKm: Number(d.searchRadiusKm ?? FALLBACK.searchRadiusKm),
      offerTimeoutSeconds: Number(
        d.offerTimeoutSeconds ?? FALLBACK.offerTimeoutSeconds,
      ),
      // The security rules refuse a depth above 10, so a larger configured
      // value would only produce writes the server rejects.
      maxDriversToTry: Math.min(
        Number(d.maxDriversToTry ?? FALLBACK.maxDriversToTry),
        FALLBACK.maxDriversToTry,
      ),
      // Same guard as routingBaseUrlProvider on the client: a blank or
      // non-HTTPS value falls back rather than issuing requests at whatever
      // ended up in the document.
      routingBaseUrl:
        typeof d.routingBaseUrl === 'string' &&
        d.routingBaseUrl.trim().startsWith('https://')
          ? d.routingBaseUrl.trim()
          : FALLBACK.routingBaseUrl,
    };
  } catch (e) {
    logger.warn('config/app unreadable, using defaults', e);
    return FALLBACK;
  }
}

/** Great-circle distance in kilometres — the same measure the client sorts by. */
function haversineKm(a: GeoPoint, b: GeoPoint): number {
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
 * Road distance in kilometres from `origin` to each destination, in order.
 *
 * The server half of the same two-stage ranking the client does: haversine
 * to shortlist, road distance to decide. One OSRM table request for the whole
 * shortlist — asking per driver would multiply the request rate against a
 * server that is rate-limited.
 *
 * Returns null when the lookup is unusable, and a null entry for a driver
 * with no road connection to the pickup. The sweep must survive both: a
 * routing outage may degrade the ordering but must never stop rides being
 * offered.
 */
async function roadDistancesKm(
  baseUrl: string,
  origin: GeoPoint,
  destinations: GeoPoint[],
): Promise<(number | null)[] | null> {
  if (destinations.length === 0) return [];

  const coords = [origin, ...destinations]
    .map((p) => `${p.longitude},${p.latitude}`)
    .join(';');
  const url = `${baseUrl}/table/v1/driving/${coords}?sources=0&annotations=distance`;

  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'ph.trikekoto.trikekoto_app' },
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) {
      logger.warn(`Table HTTP ${response.status}; ranking by straight line`);
      return null;
    }

    const body = (await response.json()) as {
      code?: string;
      distances?: (number | null)[][];
    };
    if (body.code !== 'Ok') return null;

    const row = body.distances?.[0];
    // Row is origin→[origin, ...destinations], so it is one longer.
    if (!row || row.length !== destinations.length + 1) return null;

    return row.slice(1).map((m) => (m === null ? null : m / 1000));
  } catch (e) {
    logger.warn('Table unavailable; ranking by straight line', e);
    return null;
  }
}

/**
 * Sends to one token, tolerating an expired registration.
 *
 * A token that Android has revoked returns `registration-token-not-registered`.
 * That is an ordinary outcome — reinstalls and cache clears cause it — so it
 * is cleaned up rather than logged as a failure.
 */
async function sendTo(
  token: string | null | undefined,
  notification: { title: string; body: string },
  data: Record<string, string>,
  onInvalid?: () => Promise<void>,
): Promise<void> {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification,
      data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'rides',
          // A driver is looking at the road, not the phone.
          sound: 'default',
          defaultVibrateTimings: true,
        },
      },
    });
  } catch (e: unknown) {
    const code = (e as { errorInfo?: { code?: string } })?.errorInfo?.code;
    if (code === 'messaging/registration-token-not-registered') {
      logger.info('Dropping stale FCM token');
      await onInvalid?.();
      return;
    }
    logger.error('FCM send failed', e);
  }
}

// ════════════════════════════════════════════════════════════
// 62 · Offer push — tell a driver a ride is waiting for them.
// ════════════════════════════════════════════════════════════
export const onRideOffered = onDocumentUpdated(
  { document: 'rides/{rideId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data() as Ride | undefined;
    const after = event.data?.after.data() as Ride | undefined;
    if (!after) return;

    const previous = before?.dispatch?.offeredTo ?? null;
    const current = after.dispatch?.offeredTo ?? null;

    // Only on a genuine change to a real driver. Re-sending on every ride
    // write would wake a driver repeatedly for one offer.
    if (!current || current === previous) return;
    if (after.status !== 'searching') return;

    const presence = await db.doc(`active_drivers/${current}`).get();
    const token = presence.data()?.fcmToken as string | undefined;

    await sendTo(
      token,
      {
        title: 'New ride offer',
        body: `${after.pickup?.label ?? 'Pickup'} → ${
          after.dropoff?.label ?? 'Drop-off'
        }`,
      },
      {
        type: 'ride_offer',
        rideId: event.params.rideId,
      },
      async () => {
        await presence.ref.update({ fcmToken: FieldValue.delete() });
      },
    );
  },
);

// ════════════════════════════════════════════════════════════
// 64 · Ride status pushes — keep the commuter informed.
// ════════════════════════════════════════════════════════════
export const onRideStatusChanged = onDocumentUpdated(
  { document: 'rides/{rideId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data() as Ride | undefined;
    const after = event.data?.after.data() as Ride | undefined;
    if (!after || before?.status === after.status) return;

    const driver = after.driverSnapshot?.firstName ?? 'Your driver';
    const plate = after.driverSnapshot?.plateNumber ?? '';

    const message = (() => {
      switch (after.status) {
        case 'accepted':
          return {
            title: 'Driver on the way',
            body: `${driver} is coming${plate ? ` · ${plate}` : ''}.`,
            type: 'ride_accepted',
          };
        case 'in_transit':
          return {
            title: 'On your way',
            body: 'Heading to your drop-off.',
            type: 'ride_arrived',
          };
        case 'completed':
          return {
            title: 'Ride complete',
            body: 'Rate your driver.',
            type: 'ride_completed',
          };
        default:
          return null;
      }
    })();

    if (!message) return;

    await sendTo(
      after.commuterFcmToken,
      { title: message.title, body: message.body },
      { type: message.type, rideId: event.params.rideId },
    );
  },
);

// ════════════════════════════════════════════════════════════
// 68 · Rating aggregation — closes the inflation gap.
// ════════════════════════════════════════════════════════════
/**
 * Moves the driver's rating aggregate server-side.
 *
 * The security rules can verify the *arithmetic* of a client increment —
 * exactly one vote, worth 1 to 5 — but cannot tie it to a completed ride,
 * because each document in a transaction is authorised independently. That
 * left any signed-in user able to inflate a driver's reputation.
 *
 * Here the increment is derived from the ride itself, so it can only happen
 * once, for a real completed ride, with the rating the commuter actually
 * gave.
 *
 * **Idempotent by construction.** The transaction re-reads the ride and
 * refuses if `ratingCounted` is already set, so a retried delivery — which
 * Cloud Functions makes no promise against — cannot double-count. This also
 * covers the migration window, when an older APK may still be attempting its
 * own client-side increment.
 */
export const onRideRated = onDocumentUpdated(
  { document: 'rides/{rideId}', region: REGION },
  async (event) => {
    const before = event.data?.before.data() as Ride | undefined;
    const after = event.data?.after.data() as Ride | undefined;
    if (!after) return;

    const rating = after.rating;
    const driver = after.assignedDriver;

    // Only on the transition from unrated to rated.
    if (before?.rating != null || rating == null || !driver) return;
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      logger.warn(`Ride ${event.params.rideId} has an invalid rating`, rating);
      return;
    }

    const rideRef = db.doc(`rides/${event.params.rideId}`);
    const driverRef = db.doc(`drivers/${driver}`);

    try {
      await db.runTransaction(async (tx) => {
        const [rideSnap, driverSnap] = await Promise.all([
          tx.get(rideRef),
          tx.get(driverRef),
        ]);

        if (rideSnap.data()?.ratingCounted === true) {
          logger.info(`Ride ${event.params.rideId} already counted`);
          return;
        }
        if (!driverSnap.exists) {
          logger.warn(`Driver ${driver} no longer exists`);
          return;
        }

        tx.update(driverRef, {
          ratingSum: FieldValue.increment(rating),
          ratingCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.update(rideRef, { ratingCounted: true });
      });
      logger.info(`Counted ${rating}★ for ${driver}`);
    } catch (e) {
      logger.error('Rating aggregation failed', e);
    }
  },
);

// ════════════════════════════════════════════════════════════
// 67 · Dispatch — the reason this file exists.
// ════════════════════════════════════════════════════════════
/**
 * What happens to one searching ride: expire it, offer it, or leave it.
 *
 * This is the whole match, and it lives here rather than on the commuter's
 * device because of what it has to read. Ranking drivers means reading every
 * online driver's live position, and a client that can do that is a client
 * anyone can write — the same query that finds the nearest tricycle finds
 * every tricycle, all day, for anyone who signs up. Moving it here is what
 * lets `canDiscoverDrivers()` in the rules narrow to admins.
 *
 * `online` is passed in rather than queried, because the schedule reads it
 * once for a batch of fifty rides and the callable reads it for one. Same
 * routine, two access patterns.
 *
 * Returns what it did, for the caller's log and the callable's reply. The
 * reply says only *that* — never who, never how far. A commuter learns a
 * driver's identity when one accepts, not before.
 */
type DispatchOutcome =
  | 'offered'   // an offer was written to the next candidate
  | 'waiting'   // nobody free in radius; the ride stays searching
  | 'held'      // an unexpired offer still belongs to its driver
  | 'expired'   // budget or wall clock spent; the ride is closed
  | 'skipped';  // not searching, or no pickup to rank against

async function attemptDispatch(
  ref: FirebaseFirestore.DocumentReference,
  ride: Ride,
  online: FirebaseFirestore.QueryDocumentSnapshot[],
  config: Awaited<ReturnType<typeof readConfig>>,
  now: Date,
): Promise<DispatchOutcome> {
  if (ride.status !== 'searching') return 'skipped';

  const dispatch = ride.dispatch ?? {};
  const expiresAt = dispatch.offerExpiresAt?.toDate();

  // Someone still has a live claim on this ride.
  if (expiresAt && expiresAt > now) return 'held';

  const attempted = dispatch.attemptedDrivers ?? [];
  const depth = dispatch.depth ?? 0;

  // Wall clock first, because it catches the case the candidate budget
  // structurally cannot: nobody was ever available, so no candidate was
  // ever spent, so `depth` is still 0 and always will be.
  const createdAt = ride.createdAt?.toDate();
  const searchingFor = createdAt
    ? (now.getTime() - createdAt.getTime()) / 60000
    : 0;

  if (searchingFor > SEARCH_TIMEOUT_MINUTES) {
    await ref.update({
      status: 'expired',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: 'system',
      dispatch: emptyDispatch(),
    });
    logger.info(
      `Ride ${ref.id} expired after ${Math.round(searchingFor)} min ` +
      `unmatched (${depth} candidates tried)`,
    );
    return 'expired';
  }

  if (depth >= config.maxDriversToTry) {
    await ref.update({
      status: 'expired',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: 'system',
      dispatch: emptyDispatch(),
    });
    logger.info(`Ride ${ref.id} expired after ${depth} candidates`);
    return 'expired';
  }

  const pickup = ride.pickup?.geopoint;
  if (!pickup) return 'skipped';

  // Stage one: straight-line, to apply the radius and cut the field.
  const shortlist = online
    .map((d) => ({ email: d.id, data: d.data() }))
    .filter((d) => !attempted.includes(d.email))
    .map((d) => ({
      email: d.email,
      point: d.data.position?.geopoint as GeoPoint | undefined,
      km: d.data.position?.geopoint
        ? haversineKm(pickup, d.data.position.geopoint as GeoPoint)
        : Number.POSITIVE_INFINITY,
    }))
    .filter((d) => d.point !== undefined && d.km <= config.searchRadiusKm)
    .sort((a, b) => a.km - b.km)
    .slice(0, ROAD_RANK_LIMIT);

  // Nobody free right now. Leave the ride searching — a driver may come
  // online before the budget runs out.
  if (shortlist.length === 0) return 'waiting';

  // Stage two: road distance over the shortlist decides the winner.
  // Crow-flies is wrong wherever geography does not follow the streets.
  let candidate = shortlist[0];
  if (shortlist.length > 1) {
    const roadKm = await roadDistancesKm(
      config.routingBaseUrl,
      pickup,
      shortlist.map((d) => d.point as GeoPoint),
    );
    if (roadKm) {
      // A null entry means no road connection to the pickup. Drop those
      // rather than ranking them last — offering a ride to a driver who
      // cannot reach it burns a whole offer timeout.
      const routed = shortlist
        .map((d, i) => ({ ...d, road: roadKm[i] }))
        .filter((d): d is typeof d & { road: number } => d.road !== null)
        .sort((a, b) => a.road - b.road);
      if (routed.length > 0) candidate = routed[0];
    }
  }

  await ref.update({
    dispatch: {
      offeredTo: candidate.email,
      offerSeq: (dispatch.offerSeq ?? 0) + 1,
      offerExpiresAt: new Date(
        now.getTime() + config.offerTimeoutSeconds * 1000,
      ),
      attemptedDrivers: [...attempted, candidate.email],
      depth: depth + 1,
    },
  });
  logger.info(`Ride ${ref.id} offered to ${candidate.email}`);
  return 'offered';
}

/** The online, idle drivers — the index a commuter can no longer read. */
function onlineDrivers() {
  return db
    .collection('active_drivers')
    .where('isOnline', '==', true)
    .where('availability', '==', 'idle')
    .get();
}

/**
 * The commuter's app asking for its ride to be advanced, now.
 *
 * The schedule below would get there on its own, but a minute late. Someone
 * who has just pressed *Mag-book* is watching a spinner, and a minute of it
 * is long enough to press it again — so the foreground app calls this on the
 * first tick and on every offer timeout, and the schedule stays as the net
 * for the app that was closed or backgrounded.
 *
 * **It only ever advances the caller's own ride.** The ride id is the only
 * input, and a ride whose `commuterUid` is not the caller's is refused as
 * not-found — not as permission-denied, which would confirm the id exists.
 *
 * It returns an outcome word and nothing else. No driver, no distance, no
 * count of who is nearby: a reply that carried any of those would hand back
 * exactly the information moving this off the device was meant to withhold.
 */
export const requestDispatch = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in first.');
    }

    const rideId = String((request.data ?? {}).rideId ?? '').trim();
    // Guarded because an id with a slash in it addresses a different
    // document path entirely.
    if (!rideId || rideId.length > 128 || rideId.includes('/')) {
      throw new HttpsError('invalid-argument', 'A ride id is required.');
    }

    const ref = db.collection('rides').doc(rideId);
    const snap = await ref.get();
    const ride = snap.data() as Ride | undefined;

    if (!snap.exists || !ride || ride.commuterUid !== uid) {
      throw new HttpsError('not-found', 'No such ride.');
    }
    if (ride.status !== 'searching') {
      return { outcome: 'skipped' as DispatchOutcome };
    }

    const config = await readConfig();
    const online = await onlineDrivers();
    const outcome = await attemptDispatch(
      ref, ride, online.docs, config, new Date(),
    );
    return { outcome };
  },
);

/**
 * Advances every ride whose offer has lapsed.
 *
 * [requestDispatch] only runs while the commuter's app is in the foreground.
 * This picks up the ones it abandoned: it re-offers to the next nearest
 * untried driver, and expires the ride once the candidate budget or the
 * five-minute wall clock is spent.
 *
 * Runs every minute, which is coarser than the client's 15-second cadence. A
 * foregrounded commuter still gets the fast path; this is the safety net,
 * and a per-second schedule would cost far more than it buys.
 */
export const sweepStaleRides = onSchedule(
  { schedule: 'every 1 minutes', region: REGION },
  async () => {
    const config = await readConfig();
    const now = new Date();

    const stale = await db
      .collection('rides')
      .where('status', '==', 'searching')
      .limit(50)
      .get();

    if (stale.empty) return;

    // One read for the whole batch, not one per ride.
    const online = await onlineDrivers();

    for (const doc of stale.docs) {
      await attemptDispatch(
        doc.ref, doc.data() as Ride, online.docs, config, now,
      );
    }
  },
);

function emptyDispatch(): RideDispatch {
  return {
    offeredTo: null,
    offerSeq: 0,
    offerExpiresAt: null,
    attemptedDrivers: [],
    depth: 0,
  };
}


// ════════════════════════════════════════════════════════════
// 39a · ID retention — delete what there is no longer a reason to hold.
// ════════════════════════════════════════════════════════════
/**
 * Deletes government ID submissions 90 days after they were submitted.
 *
 * This exists because the alternative was a line in a document asking an
 * administrator to remember. Retention that depends on someone remembering is
 * not retention; it is an intention. Under RA 10173 the obligation is to keep
 * sensitive personal information no longer than the purpose requires, and the
 * purpose here — confirming who somebody is, once — expires long before the
 * data does.
 *
 * **Measured from submission, not review.** Two reasons. A submission nobody
 * ever reviewed is the worst case, not an exempt one: it is the same
 * sensitive data, held with no decision to show for it, and measuring from
 * `reviewedAt` would let it sit forever. And a single clock is auditable —
 * "90 days after it arrived" is a sentence anyone can check, where "90 days
 * after review, unless unreviewed, in which case..." is a sentence nobody
 * verifies.
 *
 * **Deletes the image with the document, image first.** A document with no
 * image is a harmless orphan; an image with no document is personal data that
 * no screen will ever show and no one will think to look for. If the image
 * delete fails the document stays, so the pair is retried tomorrow rather
 * than being silently half-removed.
 *
 * **The verification outcome is deleted too**, deliberately. Nothing in the
 * app gates on ID status, so keeping "this person was verified in September"
 * would mean retaining a record of a check for a permission that does not
 * exist. If gating is ever added, a boolean on the subject's own document is
 * the thing to keep — not the ID.
 *
 * Daily, not hourly: the deadline is 90 days, so a few hours of imprecision
 * costs nothing and 24× fewer invocations do.
 */
const ID_RETENTION_DAYS = 90;

export const purgeExpiredIds = onSchedule(
  { schedule: 'every day 03:15', timeZone: 'Asia/Manila', region: REGION },
  async () => {
    const cutoff = new Date(Date.now() - ID_RETENTION_DAYS * 24 * 60 * 60 * 1000);

    const expired = await db
      .collection('id_submissions')
      .where('submittedAt', '<', cutoff)
      // Bounded so one run cannot become an unbounded delete storm on a
      // backlog. Whatever is left is picked up tomorrow.
      .limit(200)
      .get();

    if (expired.empty) return;

    const bucket = getStorage().bucket();
    let removed = 0;
    let imageFailures = 0;

    for (const snap of expired.docs) {
      const uid = snap.id;
      const path = (snap.data().idPhotoPath as string | undefined)
        ?? `ids/${uid}/card`;

      try {
        // ignoreNotFound: an already-absent object is the desired end state,
        // not an error — a subject may have withdrawn the image already.
        await bucket.file(path).delete({ ignoreNotFound: true });
      } catch (e) {
        // Leave the document. It is the only remaining pointer to the image,
        // and tomorrow's run will try again.
        imageFailures++;
        logger.error(`Retention: could not delete ${path}, keeping document`, e);
        continue;
      }

      await snap.ref.delete();
      removed++;
    }

    // Counts only. Logging which uid had an ID deleted would recreate, in the
    // log retention window, exactly the record this job exists to remove.
    logger.info(
      `Retention: removed ${removed} ID submissions older than ` +
      `${ID_RETENTION_DAYS} days` +
      (imageFailures > 0 ? `; ${imageFailures} image deletes deferred` : ''),
    );
  },
);


// ════════════════════════════════════════════════════════════
// 37c · Account deletion — erase the person, keep the record.
// ════════════════════════════════════════════════════════════
/**
 * Strips a deleted rider's personal details from their ride history.
 *
 * Rides carry `commuterName` and `commuterPhone` denormalised, because a
 * driver has to know who they are collecting and cannot read `riders/`. That
 * denormalisation is what makes deletion incomplete on its own: removing the
 * profile would leave the name and number in every ride the person ever took,
 * so "delete my account" would be untrue in the one way that matters.
 *
 * Rides themselves are never deleted — `allow delete: if false`, for everyone
 * including admins, because they are the audit trail a TODA chapter and a
 * dispute both depend on. So the answer is not to remove the record but to
 * remove the person from it: timestamps, coordinates, driver, status and
 * rating all survive; the name becomes "Deleted account", the phone and photo
 * go, and `commuterUid` is cleared so the remaining rows cannot be joined back
 * together into one person's travel history.
 *
 * Runs on the deletion of `riders/{uid}`, which the rider performs themselves.
 * A client cannot do this: the ride rules admit no clause for rewriting these
 * fields, and widening them so a commuter could edit their own historical
 * rides would be a far larger hole than the one it closed.
 */
export const onRiderDeleted = onDocumentDeleted(
  { document: 'riders/{riderUid}', region: REGION },
  async (event) => {
    const uid = event.params.riderUid;

    // Bounded per run. A rider with an implausible number of rides should not
    // turn one deletion into a multi-minute write storm; the tail is picked
    // up by re-running, and the fields left behind are already the ones this
    // job exists to clear.
    const rides = await db
      .collection('rides')
      .where('commuterUid', '==', uid)
      .limit(400)
      .get();

    if (rides.empty) {
      logger.info('Rider deleted with no ride history');
      return;
    }

    // Batched at 400, below Firestore's 500-write limit, so a large history
    // commits rather than failing wholesale.
    const batch = db.batch();
    for (const snap of rides.docs) {
      batch.update(snap.ref, {
        commuterUid: null,
        commuterName: 'Deleted account',
        commuterPhone: null,
        commuterPhotoUrl: null,
        commuterFcmToken: null,
      });
    }
    await batch.commit();

    // A count, never the uid. Logging it would put the identifier back into
    // the log retention window, which is the record this job just removed.
    logger.info(`Anonymised ${rides.size} rides for a deleted account`);
  },
);
