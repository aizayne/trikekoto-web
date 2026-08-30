import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/collection_paths.dart';

/// A document in `active_drivers/{driverEmail}` — the dispatch index.
///
/// Rewritten every few seconds while the driver is online, and readable by
/// every signed-in commuter so the greedy nearest-driver search can run on the
/// device. It therefore carries **no name, phone, or plate**: identifying
/// details only reach a commuter once a ride is actually accepted.
class ActiveDriver {
  const ActiveDriver({
    required this.email,
    required this.isOnline,
    required this.availability,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    this.accuracy,
    this.heading,
    this.speed,
    this.currentRideId,
    this.fcmToken,
    this.updatedAt,
  });

  final String email;
  final bool isOnline;
  final String availability;
  final double latitude;
  final double longitude;
  final String geohash;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final String? currentRideId;
  final String? fcmToken;
  final Timestamp? updatedAt;

  bool get isAvailable =>
      isOnline && availability == DriverAvailability.idle;

  /// False when the document carries no usable coordinates — an unmigrated
  /// row, or a presence write that landed before the first GPS fix. Such a
  /// document parses as 0,0 (Null Island), which is a real point on the
  /// globe, so the dispatch sweep must exclude it explicitly rather than
  /// relying on the radius filter to hide it.
  bool get hasPosition =>
      geohash.isNotEmpty && !(latitude == 0 && longitude == 0);

  GeoPoint get geopoint => GeoPoint(latitude, longitude);

  factory ActiveDriver.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
    SnapshotOptions? _,
  ) =>
      ActiveDriver.fromMap(snap.data(), snap.id);

  /// Parsing, separated from the Firestore plumbing so it can be exercised
  /// without a live snapshot.
  ///
  /// Presence documents from the web build nest coordinates under
  /// `location: {lat, lng}` rather than `position`, so an unmigrated row
  /// parses with a zeroed position instead of throwing mid-sweep. Callers
  /// filter those out via [hasPosition].
  factory ActiveDriver.fromMap(Map<String, dynamic>? data, String id) {
    final d = data ?? const <String, dynamic>{};
    final position = (d['position'] as Map?)?.cast<String, dynamic>() ?? const {};
    final point = position['geopoint'] as GeoPoint?;
    return ActiveDriver(
      email: d['email'] as String? ?? id,
      isOnline: d['isOnline'] as bool? ?? false,
      availability: d['availability'] as String? ?? DriverAvailability.idle,
      latitude: point?.latitude ?? 0,
      longitude: point?.longitude ?? 0,
      geohash: position['geohash'] as String? ?? '',
      accuracy: (d['accuracy'] as num?)?.toDouble(),
      heading: (d['heading'] as num?)?.toDouble(),
      speed: (d['speed'] as num?)?.toDouble(),
      currentRideId: d['currentRideId'] as String?,
      fcmToken: d['fcmToken'] as String?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => presencePayload(
        email: email,
        isOnline: isOnline,
        availability: availability,
        latitude: latitude,
        longitude: longitude,
        geohash: geohash,
        accuracy: accuracy,
        heading: heading,
        speed: speed,
        currentRideId: currentRideId,
        fcmToken: fcmToken,
      );

  /// The exact shape the `active_drivers` rule validates.
  ///
  /// `updatedAt` must be `serverTimestamp()`: the rule requires it to equal
  /// `request.time`, so a client cannot backdate a ping to look fresher — or
  /// staler — than it is.
  static Map<String, dynamic> presencePayload({
    required String email,
    required bool isOnline,
    required String availability,
    required double latitude,
    required double longitude,
    required String geohash,
    double? accuracy,
    double? heading,
    double? speed,
    String? currentRideId,
    String? fcmToken,
  }) =>
      {
        'email': normalizeEmail(email),
        'isOnline': isOnline,
        'availability': availability,
        'position': {
          'geohash': geohash,
          'geopoint': GeoPoint(latitude, longitude),
        },
        'accuracy': accuracy,
        'heading': heading,
        'speed': speed,
        'currentRideId': currentRideId,
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
