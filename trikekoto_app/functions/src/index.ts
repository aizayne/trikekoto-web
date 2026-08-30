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
 * Deploying requires the Blaze plan. Everything here typechecks and is ready
 * to ship the moment billing is enabled.
 */

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, GeoPoint, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';

initializeApp();
const db = getFirestore();

const REGION = 'asia-southeast1';

/** Mirrors DispatchDefaults in the Flutter client. */
const FALLBACK = {
  searchRadiusKm: 5,
  offerTimeoutSeconds: 15,
  maxDriversToTry: 10,
};

type RideDispatch = {
  offeredTo?: string | null;
  offerSeq?: number;
  offerExpiresAt?: FirebaseFirestore.Timestamp | null;
  attemptedDrivers?: string[];
  depth?: number;
};

type Ride = {
  status?: string;
  rating?: number | null;
  ratingCounted?: boolean;
  commuterName?: string;
  commuterFcmToken?: string | null;
  pickup?: { label?: string; geopoint?: GeoPoint };
  dropoff?: { label?: string };
  dispatch?: RideDispatch;
  assignedDriver?: string | null;
  driverSnapshot?: { firstName?: string; plateNumber?: string } | null;
  fareEstimate?: number | null;
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
            body: after.fareEstimate
              ? `Estimated fare ₱${after.fareEstimate}. Rate your driver.`
              : 'Rate your driver.',
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
// 67 · Dispatch sweep — the reason this file exists.
// ════════════════════════════════════════════════════════════
/**
 * Advances every ride whose offer has lapsed.
 *
 * The client-side sweep only runs while the commuter's app is in the
 * foreground. This picks up the ones it abandoned: it re-offers to the next
 * nearest untried driver, and expires the ride once the candidate budget is
 * spent.
 *
 * Runs every minute, which is coarser than the 15-second client cadence. A
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

    const online = await db
      .collection('active_drivers')
      .where('isOnline', '==', true)
      .where('availability', '==', 'idle')
      .get();

    for (const doc of stale.docs) {
      const ride = doc.data() as Ride;
      const dispatch = ride.dispatch ?? {};
      const expiresAt = dispatch.offerExpiresAt?.toDate();

      // Someone still has a live claim on this ride.
      if (expiresAt && expiresAt > now) continue;

      const attempted = dispatch.attemptedDrivers ?? [];
      const depth = dispatch.depth ?? 0;

      if (depth >= config.maxDriversToTry) {
        await doc.ref.update({
          status: 'expired',
          cancelledAt: FieldValue.serverTimestamp(),
          cancelledBy: 'system',
          dispatch: emptyDispatch(),
        });
        logger.info(`Ride ${doc.id} expired after ${depth} candidates`);
        continue;
      }

      const pickup = ride.pickup?.geopoint;
      if (!pickup) continue;

      const candidate = online.docs
        .map((d) => ({ email: d.id, data: d.data() }))
        .filter((d) => !attempted.includes(d.email))
        .map((d) => ({
          email: d.email,
          km: d.data.position?.geopoint
            ? haversineKm(pickup, d.data.position.geopoint as GeoPoint)
            : Number.POSITIVE_INFINITY,
        }))
        .filter((d) => d.km <= config.searchRadiusKm)
        .sort((a, b) => a.km - b.km)[0];

      // Nobody free right now. Leave the ride searching — a driver may come
      // online before the budget runs out.
      if (!candidate) continue;

      await doc.ref.update({
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
      logger.info(`Ride ${doc.id} re-offered to ${candidate.email}`);
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
