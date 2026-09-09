import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/drivers/data/active_driver.dart';
import '../../features/drivers/data/driver.dart';
import '../../features/feedback/data/feedback_report.dart';
import '../../features/rides/data/ride.dart';
import 'collection_paths.dart';

/// Typed entry points into Firestore.
///
/// Two jobs: hand back `withConverter` references so no screen ever touches a
/// raw `Map<String, dynamic>`, and hold the canonical queries. Every query here
/// is one the security rules provably allow and `firestore.indexes.json`
/// covers — building queries ad hoc elsewhere is how you end up with a
/// `permission-denied` or a missing-index error in production.
class FirestoreRefs {
  FirestoreRefs(this._db);

  final FirebaseFirestore _db;

  // ── Collections ────────────────────────────────────────────

  CollectionReference<Driver> get drivers =>
      _db.collection(FsCollections.drivers).withConverter<Driver>(
            fromFirestore: Driver.fromFirestore,
            toFirestore: (d, _) => d.toFirestore(),
          );

  DocumentReference<Driver> driver(String email) =>
      drivers.doc(normalizeEmail(email));

  /// Rider profiles. Keyed by uid — the rules admit only the caller's own
  /// document, so there is no collection-level query for these at all.
  DocumentReference<Map<String, dynamic>> rider(String uid) =>
      _db.collection(FsCollections.riders).doc(uid);

  CollectionReference<ActiveDriver> get activeDrivers => _db
      .collection(FsCollections.activeDrivers)
      .withConverter<ActiveDriver>(
        fromFirestore: ActiveDriver.fromFirestore,
        toFirestore: (d, _) => d.toFirestore(),
      );

  DocumentReference<ActiveDriver> activeDriver(String email) =>
      activeDrivers.doc(normalizeEmail(email));

  CollectionReference<Ride> get rides =>
      _db.collection(FsCollections.rides).withConverter<Ride>(
            fromFirestore: Ride.fromFirestore,
            toFirestore: (r, _) => r.toFirestore(),
          );

  DocumentReference<Ride> ride(String rideId) => rides.doc(rideId);

  CollectionReference<FeedbackReport> get feedback => _db
      .collection(FsCollections.feedback)
      .withConverter<FeedbackReport>(
        fromFirestore: FeedbackReport.fromFirestore,
        toFirestore: (f, _) => f.toFirestore(),
      );

  DocumentReference<Map<String, dynamic>> adminDoc(String email) =>
      _db.collection(FsCollections.admins).doc(normalizeEmail(email));

  DocumentReference<Map<String, dynamic>> get appConfig =>
      _db.collection(FsCollections.config).doc(FsCollections.configAppDoc);

  // ── Dispatch ───────────────────────────────────────────────

  /// Every driver available to be matched.
  ///
  /// For a single TODA chapter this returns tens of documents, so the greedy
  /// search sorts them by Haversine distance on the device — exact, one query,
  /// and cheaper than the eight-cell neighbour scan a geohash radius search
  /// needs. Switch to [availableDriversInGeohashRange] when the fleet grows.
  Query<ActiveDriver> get availableDrivers => activeDrivers
      .where('isOnline', isEqualTo: true)
      .where('availability', isEqualTo: DriverAvailability.idle);

  /// Geohash-prefix variant, for when the fleet outgrows a full scan. Call it
  /// once per cell returned by the geohash neighbour calculation, then filter
  /// the union by true distance — geohash cells are rectangles, so the results
  /// are a superset of the radius.
  Query<ActiveDriver> availableDriversInGeohashRange(String start, String end) =>
      availableDrivers
          .orderBy('position.geohash')
          .startAt([start]).endAt([end]);

  // ── Ride queries ───────────────────────────────────────────

  /// Rides currently being offered to this driver. Backed by the
  /// `dispatch.offeredTo + status + createdAt` index; the read rule admits
  /// each document via `isOfferedDriver()`.
  Query<Ride> offersFor(String driverEmail) => rides
      .where('dispatch.offeredTo', isEqualTo: normalizeEmail(driverEmail))
      .where('status', isEqualTo: RideStatus.searching.wire)
      .orderBy('createdAt', descending: true);

  /// The driver's in-progress ride, if any — used to restore state after the
  /// app is killed mid-trip.
  Query<Ride> activeRideFor(String driverEmail) => rides
      .where('assignedDriver', isEqualTo: normalizeEmail(driverEmail))
      .where('status', whereIn: [
        RideStatus.accepted.wire,
        RideStatus.inTransit.wire,
      ])
      .orderBy('createdAt', descending: true)
      .limit(1);

  Query<Ride> rideHistoryFor(String driverEmail) => rides
      .where('assignedDriver', isEqualTo: normalizeEmail(driverEmail))
      .where('status', isEqualTo: RideStatus.completed.wire)
      .orderBy('createdAt', descending: true);

  Query<Ride> ridesForCommuter(String uid) => rides
      .where('commuterUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true);

  // ── Admin queries ──────────────────────────────────────────

  Query<Driver> get pendingDrivers => drivers
      .where('status', isEqualTo: DriverStatus.pending)
      .orderBy('createdAt');

  Query<FeedbackReport> get openFeedback => feedback
      .where('resolved', isEqualTo: false)
      .orderBy('createdAt', descending: true);

  /// Every ride created since [since], for the analytics window.
  ///
  /// No status filter, because the panel needs the failures as much as the
  /// successes — a completion rate computed without cancellations is just a
  /// ride count. A range on a single field needs no composite index; Firestore
  /// indexes each field on its own by default.
  ///
  /// [limit] is a cost ceiling, not a page size. Each document in the window
  /// bills one read, and an admin who leaves the panel on "30 days" should not
  /// be able to spend an unbounded number of them. Callers must treat a full
  /// result as possibly truncated and say so.
  Query<Ride> ridesSince(DateTime since, {int limit = 2000}) => rides
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('createdAt', descending: true)
      .limit(limit);
}
