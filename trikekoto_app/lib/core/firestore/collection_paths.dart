/// Canonical Firestore paths and field names.
///
/// Every collection name and every field the security rules mention lives
/// here exactly once. A typo in a string literal is a runtime
/// `permission-denied` with no stack trace pointing at the cause — this file
/// is what keeps that from happening.
///
/// See `SCHEMA.md` for the full field reference.
library;

/// Canonicalises an email for use as a document ID.
///
/// Firebase Auth preserves the casing the user typed but treats addresses
/// case-insensitively for uniqueness, so `Juan@x.com` and `juan@x.com` are one
/// account that would become two documents. Every read or write that keys off
/// an email must pass through here; the rules call `.lower()` on their side so
/// the two representations always agree.
String normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

class FsCollections {
  const FsCollections._();

  static const drivers = 'drivers';

  /// Rider profiles, keyed by uid rather than phone number — a phone number
  /// is personal data and should not be a key anyone can enumerate.
  static const riders = 'riders';
  static const activeDrivers = 'active_drivers';
  static const rides = 'rides';
  static const admins = 'admins';
  static const feedback = 'feedback';
  static const config = 'config';

  /// The singleton runtime-config document: `config/app`.
  static const configAppDoc = 'app';
}

/// `drivers.status` — the verification state machine owned by admins.
class DriverStatus {
  const DriverStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const suspended = 'suspended';
  static const rejected = 'rejected';

  static const all = [pending, approved, suspended, rejected];
}

/// `active_drivers.availability`.
class DriverAvailability {
  const DriverAvailability._();

  static const idle = 'idle';
  static const onRide = 'on_ride';
}

/// `rides.status`.
///
/// `searching → accepted → in_transit → completed`, with `cancelled` and
/// `expired` as terminal exits. The rules encode each legal transition
/// separately, so adding a value here means adding a clause there.
enum RideStatus {
  searching('searching'),
  accepted('accepted'),
  inTransit('in_transit'),
  completed('completed'),
  cancelled('cancelled'),
  expired('expired');

  const RideStatus(this.wire);

  /// The string actually stored in Firestore and compared by the rules.
  final String wire;

  static RideStatus fromWire(String? value) => RideStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => RideStatus.searching,
      );

  bool get isTerminal =>
      this == completed || this == cancelled || this == expired;

  /// True while the trike is en route or carrying the commuter — the states
  /// in which the driver streams GPS onto the ride document.
  bool get isLive => this == accepted || this == inTransit;
}

/// `rides.cancelledBy`.
class CancelledBy {
  const CancelledBy._();

  static const commuter = 'commuter';
  static const driver = 'driver';

  /// Used when the greedy search exhausts its 10 candidates.
  static const system = 'system';
}

/// `feedback.category` / `feedback.role`.
class FeedbackCategory {
  const FeedbackCategory._();

  static const issue = 'issue';
  static const suggestion = 'suggestion';
  static const question = 'question';
  static const other = 'other';

  static const all = [issue, suggestion, question, other];
}

class FeedbackRole {
  const FeedbackRole._();

  static const commuter = 'commuter';
  static const driver = 'driver';
  static const unknown = 'unknown';
}

/// Dispatch limits. These mirror `config/app` and are the fallbacks used
/// before that document loads — the rules independently cap `depth` and
/// `attemptedDrivers` at 10, so raising [maxDriversToTry] beyond that
/// requires a rules change too.
class DispatchDefaults {
  const DispatchDefaults._();

  static const searchRadiusKm = 5.0;
  static const offerTimeout = Duration(seconds: 15);
  static const maxDriversToTry = 10;

  /// How many straight-line-nearest drivers get re-ranked by road distance.
  ///
  /// Road ranking costs one OSRM request per sweep, and the request carries
  /// every shortlisted coordinate in its URL. Eight is enough that the true
  /// nearest is essentially always inside it — a driver ranked ninth by
  /// crow-flies is not going to be first by road — while keeping the URL
  /// short and the matrix cheap.
  ///
  /// Not exposed in `config/app`: raising it would widen the query the
  /// security rules validate, and the value that actually matters
  /// operationally is `searchRadiusKm`, which is already editable.
  static const roadRankLimit = 8;
}
