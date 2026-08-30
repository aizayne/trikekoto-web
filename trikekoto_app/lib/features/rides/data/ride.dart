import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/collection_paths.dart';

/// Narrows a Firestore value to a map, or null if it is anything else.
///
/// Nested fields are not guaranteed to hold the shape the current schema
/// expects — the web build wrote several of them differently — and a bare
/// `as Map?` cast throws on a mismatch, failing the whole query.
Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;

/// A pickup or drop-off point: what the commuter typed, plus where it is.
class RidePlace {
  const RidePlace({required this.label, this.geopoint});

  final String label;
  final GeoPoint? geopoint;

  /// Accepts either the current `{label, geopoint}` map or the bare string
  /// the web build stored, so a legacy ride keeps its label rather than
  /// crashing the parse. Those rides have no coordinates at all, which is
  /// why [geopoint] stays null and dispatch skips them.
  factory RidePlace.fromAny(Object? value) {
    if (value is String) return RidePlace(label: value);
    final m = _asMap(value);
    return RidePlace(
      label: m?['label'] as String? ?? '',
      geopoint: m?['geopoint'] is GeoPoint ? m!['geopoint'] as GeoPoint : null,
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'geopoint': geopoint};
}

/// The greedy search's state machine, stored inline on the ride.
///
/// While `status == 'searching'` the commuter's device owns this map and
/// rewrites it as the search widens. The rules allow the commuter to change
/// `dispatch` and nothing else during that phase, and allow the currently
/// offered driver to clear it when declining.
class RideDispatch {
  const RideDispatch({
    this.offeredTo,
    this.offerSeq = 0,
    this.offerExpiresAt,
    this.attemptedDrivers = const [],
    this.depth = 0,
  });

  /// The one driver currently being pinged. Only this driver may accept.
  final String? offeredTo;

  /// Increments on every ping, so a driver can tell a stale offer from a new
  /// one when snapshots arrive out of order.
  final int offerSeq;

  /// `now + 15s` — drives the countdown on the driver's offer card.
  final Timestamp? offerExpiresAt;

  /// Everyone already pinged; the next sweep skips them. Capped at 10 by the
  /// rules as well as here.
  final List<String> attemptedDrivers;

  /// How far down the distance-sorted candidate list the search has walked.
  /// Monotonic — the rules reject any update that lowers it.
  final int depth;

  bool get isExhausted => depth >= DispatchDefaults.maxDriversToTry;

  bool get hasLiveOffer =>
      offeredTo != null &&
      offerExpiresAt != null &&
      offerExpiresAt!.toDate().isAfter(DateTime.now());

  factory RideDispatch.fromMap(Map<String, dynamic>? m) => RideDispatch(
        offeredTo: m?['offeredTo'] as String?,
        offerSeq: (m?['offerSeq'] as num?)?.toInt() ?? 0,
        offerExpiresAt: m?['offerExpiresAt'] as Timestamp?,
        attemptedDrivers:
            (m?['attemptedDrivers'] as List?)?.cast<String>() ?? const [],
        depth: (m?['depth'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'offeredTo': offeredTo,
        'offerSeq': offerSeq,
        'offerExpiresAt': offerExpiresAt,
        'attemptedDrivers': attemptedDrivers,
        'depth': depth,
      };

  /// Advances the search to [driverEmail]: records the previous candidate as
  /// attempted, bumps the sequence and depth, and starts a fresh 15s window.
  RideDispatch offerTo(String driverEmail, {Duration? timeout}) {
    final email = normalizeEmail(driverEmail);
    return RideDispatch(
      offeredTo: email,
      offerSeq: offerSeq + 1,
      offerExpiresAt: Timestamp.fromDate(
        DateTime.now().add(timeout ?? DispatchDefaults.offerTimeout),
      ),
      attemptedDrivers: attemptedDrivers.contains(email)
          ? attemptedDrivers
          : [...attemptedDrivers, email],
      depth: depth + 1,
    );
  }

  /// Clears the current offer without advancing — what a declining driver
  /// writes.
  RideDispatch declinedBy(String driverEmail) {
    final email = normalizeEmail(driverEmail);
    return RideDispatch(
      offeredTo: null,
      offerSeq: offerSeq,
      offerExpiresAt: null,
      attemptedDrivers: attemptedDrivers.contains(email)
          ? attemptedDrivers
          : [...attemptedDrivers, email],
      depth: depth,
    );
  }
}

/// The driver details copied onto the ride at accept time.
///
/// This is why `drivers/` need not be publicly readable: the commuter gets
/// exactly the fields they need for this one ride, and nothing about any other
/// driver in the fleet. The rules verify these against the real profile, so a
/// driver cannot advertise someone else's plate number.
class RideDriverSnapshot {
  const RideDriverSnapshot({
    required this.email,
    required this.firstName,
    required this.phone,
    required this.plateNumber,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  final String email;
  final String firstName;
  final String phone;
  final String plateNumber;
  final int ratingSum;
  final int ratingCount;

  double? get ratingAverage =>
      ratingCount == 0 ? null : ratingSum / ratingCount;

  factory RideDriverSnapshot.fromMap(Map<String, dynamic> m) =>
      RideDriverSnapshot(
        email: m['email'] as String? ?? '',
        firstName: m['firstName'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        plateNumber: m['plateNumber'] as String? ?? '',
        ratingSum: (m['ratingSum'] as num?)?.toInt() ?? 0,
        ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'firstName': firstName,
        'phone': phone,
        'plateNumber': plateNumber,
        'ratingSum': ratingSum,
        'ratingCount': ratingCount,
      };
}

/// A document in `rides/{rideId}`.
class Ride {
  const Ride({
    required this.id,
    required this.commuterUid,
    required this.commuterName,
    required this.commuterPhone,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.dispatch,
    this.notes,
    this.assignedDriver,
    this.driverSnapshot,
    this.driverLocation,
    this.driverLocationAt,
    this.scheduledFor,
    this.fareEstimate,
    this.distanceKm,
    this.rating,
    this.feedback,
    this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.ratedAt,
  });

  final String id;
  final String commuterUid;
  final String commuterName;
  final String commuterPhone;
  final RidePlace pickup;
  final RidePlace dropoff;
  final String? notes;
  final RideStatus status;
  final RideDispatch dispatch;
  final String? assignedDriver;
  final RideDriverSnapshot? driverSnapshot;

  /// Mirrored here by the driver so the commuter can track the trike from
  /// their own ride document, without read access to `active_drivers`.
  final GeoPoint? driverLocation;
  final Timestamp? driverLocationAt;

  final Timestamp? scheduledFor;
  final num? fareEstimate;
  final num? distanceKm;
  final int? rating;
  final String? feedback;
  final Timestamp? createdAt;
  final Timestamp? acceptedAt;
  final Timestamp? startedAt;
  final Timestamp? completedAt;
  final Timestamp? cancelledAt;
  final String? cancelledBy;
  final Timestamp? ratedAt;

  bool get isRateable => status == RideStatus.completed && rating == null;

  factory Ride.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
    SnapshotOptions? _,
  ) =>
      Ride.fromMap(snap.data(), snap.id);

  /// Parsing, separated from the Firestore plumbing so it can be exercised
  /// without a live snapshot.
  ///
  /// Rides written by the previous web build have no `commuterUid`,
  /// `dispatch`, or `driverSnapshot` at all. An admin listing every ride
  /// still receives them, so absence has to parse rather than throw.
  factory Ride.fromMap(Map<String, dynamic>? data, String id) {
    final d = data ?? const <String, dynamic>{};
    final snapshot = _asMap(d['driverSnapshot']);
    return Ride(
      id: id,
      commuterUid: d['commuterUid'] as String? ?? '',
      commuterName: d['commuterName'] as String? ?? '',
      commuterPhone: d['commuterPhone'] as String? ?? '',
      pickup: RidePlace.fromAny(d['pickup']),
      dropoff: RidePlace.fromAny(d['dropoff']),
      notes: d['notes'] as String?,
      status: RideStatus.fromWire(d['status'] as String?),
      dispatch: RideDispatch.fromMap(_asMap(d['dispatch'])),
      assignedDriver: d['assignedDriver'] as String?,
      driverSnapshot:
          snapshot == null ? null : RideDriverSnapshot.fromMap(snapshot),
      // The web build stored this as a {lat, lng} map rather than a
      // GeoPoint, so the cast has to be guarded, not assumed.
      driverLocation:
          d['driverLocation'] is GeoPoint ? d['driverLocation'] as GeoPoint : null,
      driverLocationAt: d['driverLocationAt'] as Timestamp?,
      scheduledFor: d['scheduledFor'] as Timestamp?,
      fareEstimate: d['fareEstimate'] as num?,
      distanceKm: d['distanceKm'] as num?,
      rating: (d['rating'] as num?)?.toInt(),
      feedback: d['feedback'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
      acceptedAt: d['acceptedAt'] as Timestamp?,
      startedAt: d['startedAt'] as Timestamp?,
      completedAt: d['completedAt'] as Timestamp?,
      cancelledAt: d['cancelledAt'] as Timestamp?,
      cancelledBy: d['cancelledBy'] as String?,
      ratedAt: d['ratedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'commuterUid': commuterUid,
        'commuterName': commuterName,
        'commuterPhone': commuterPhone,
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        'notes': notes,
        'status': status.wire,
        'dispatch': dispatch.toMap(),
        'assignedDriver': assignedDriver,
        'driverSnapshot': driverSnapshot?.toMap(),
        'driverLocation': driverLocation,
        'driverLocationAt': driverLocationAt,
        'scheduledFor': scheduledFor,
        'fareEstimate': fareEstimate,
        'distanceKm': distanceKm,
        'rating': rating,
        'feedback': feedback,
        'createdAt': createdAt,
        'acceptedAt': acceptedAt,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'cancelledAt': cancelledAt,
        'cancelledBy': cancelledBy,
        'ratedAt': ratedAt,
      };
}

/// Write payloads shaped to satisfy each clause of the `rides` update rule.
///
/// Each builder touches exactly the fields its clause allows via
/// `onlyChanged([...])`. Adding a field to one of these without adding it to
/// the matching rule produces a `permission-denied` at runtime — keep the two
/// in step.
class RideWrites {
  const RideWrites._();

  /// Clause: `create`. Every field the rule type-checks must be present, and
  /// the ride must start unassigned and unrated.
  static Map<String, dynamic> create({
    required String commuterUid,
    required String commuterName,
    required String commuterPhone,
    required RidePlace pickup,
    required RidePlace dropoff,
    String? notes,
    Timestamp? scheduledFor,
    num? fareEstimate,
    num? distanceKm,
    String? commuterFcmToken,
  }) =>
      {
        'commuterUid': commuterUid,
        'commuterName': commuterName.trim(),
        'commuterPhone': commuterPhone.trim(),
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
        'status': RideStatus.searching.wire,
        'dispatch': const RideDispatch().toMap(),
        'assignedDriver': null,
        'driverSnapshot': null,
        'driverLocation': null,
        'driverLocationAt': null,
        'scheduledFor': scheduledFor,
        'fareEstimate': fareEstimate,
        'distanceKm': distanceKm,
        'rating': null,
        'feedback': null,
        // Lets a Cloud Function tell this commuter their driver accepted or
        // arrived. Stored on the ride rather than a profile because commuters
        // are anonymous and have no document of their own.
        'commuterFcmToken': commuterFcmToken,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Clause 1 — commuter widens the greedy search.
  static Map<String, dynamic> offerTo(RideDispatch next) =>
      {'dispatch': next.toMap()};

  /// Clause 2 — commuter cancels, or the search gives up after 10 candidates.
  static Map<String, dynamic> cancelByCommuter({bool exhausted = false}) => {
        'status':
            (exhausted ? RideStatus.expired : RideStatus.cancelled).wire,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': exhausted ? CancelledBy.system : CancelledBy.commuter,
        'dispatch': const RideDispatch().toMap(),
      };

  /// Clause 3 — commuter rates a completed ride. Write-once: the rule requires
  /// the previous `rating` to be null.
  static Map<String, dynamic> rate({required int stars, String? feedback}) => {
        'rating': stars,
        'feedback': (feedback?.trim().isEmpty ?? true) ? null : feedback!.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      };

  /// Clause 4 — the offered driver accepts. Run inside `runTransaction`; the
  /// rule additionally requires the pre-image to be unassigned, so a client
  /// that skips the transaction still cannot steal an assigned ride.
  static Map<String, dynamic> accept({
    required String driverEmail,
    required RideDriverSnapshot snapshot,
    GeoPoint? driverLocation,
  }) =>
      {
        'status': RideStatus.accepted.wire,
        'assignedDriver': normalizeEmail(driverEmail),
        'driverSnapshot': snapshot.toMap(),
        'driverLocation': driverLocation,
        'driverLocationAt':
            driverLocation == null ? null : FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'dispatch': const RideDispatch().toMap(),
      };

  /// Clause 5 — the offered driver declines.
  static Map<String, dynamic> decline({
    required String driverEmail,
    required RideDispatch current,
  }) =>
      {'dispatch': current.declinedBy(driverEmail).toMap()};

  /// Clause 6 — assigned driver advances the lifecycle.
  static Map<String, dynamic> startTrip() => {
        'status': RideStatus.inTransit.wire,
        'startedAt': FieldValue.serverTimestamp(),
      };

  /// Closes the ride, recording what it cost.
  ///
  /// [distanceKm] and [fareEstimate] are optional because a driver whose GPS
  /// never produced a fix must still be able to complete the trip — the rule
  /// permits them absent for exactly that reason. When absent, the fare is
  /// settled in cash off-app, as it is today.
  static Map<String, dynamic> complete({
    double? distanceKm,
    num? fareEstimate,
  }) =>
      {
        'status': RideStatus.completed.wire,
        'completedAt': FieldValue.serverTimestamp(),
        'distanceKm': ?distanceKm,
        'fareEstimate': ?fareEstimate,
      };

  static Map<String, dynamic> cancelByDriver() => {
        'status': RideStatus.cancelled.wire,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': CancelledBy.driver,
      };

  /// Clause 7 — assigned driver streams GPS to the commuter's ride document.
  static Map<String, dynamic> locationPing(GeoPoint position) => {
        'driverLocation': position,
        'driverLocationAt': FieldValue.serverTimestamp(),
      };

  /// The `drivers/{email}` half of rating a ride. The rule verifies the
  /// arithmetic — exactly one vote, worth 1 to 5 — so these must be atomic
  /// increments, not read-modify-write.
  static Map<String, dynamic> ratingIncrement(int stars) => {
        'ratingSum': FieldValue.increment(stars),
        'ratingCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
