import 'package:cloud_firestore/cloud_firestore.dart';

/// A document in `riders/{uid}`.
///
/// Keyed by **uid**, not by phone number — unlike `drivers/{email}`. A driver's
/// email is their working identity within the TODA and is shown to admins; a
/// rider's phone number is personal data that should not be a public key
/// anyone can enumerate or guess. The uid is opaque and already what the ride
/// documents carry.
///
/// Optional by design. Booking still works with no account at all, and a rider
/// who never signs up never gets one of these.
class Rider {
  const Rider({
    required this.uid,
    required this.name,
    required this.phone,
    this.profilePhotoUrl,
    this.savedAddresses = const [],
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;

  /// E.164, as Firebase Auth reports it — `+639171234567`.
  final String phone;

  final String? profilePhotoUrl;
  final List<SavedAddress> savedAddresses;

  /// Sum and count rather than an average.
  ///
  /// Same shape as the driver aggregate: an average alone cannot be updated
  /// correctly without knowing how many ratings it came from, and a rules-
  /// checked increment needs both halves.
  final int ratingSum;
  final int ratingCount;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  /// Null until a driver has rated them, rather than an optimistic 5.0 or a
  /// punitive 0 — a new rider has no record, which is different from a bad one.
  double? get rating => ratingCount == 0 ? null : ratingSum / ratingCount;

  factory Rider.fromMap(Map<String, dynamic>? m, String uid) {
    final data = m ?? const <String, dynamic>{};
    return Rider(
      uid: uid,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      savedAddresses: (data['savedAddresses'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => SavedAddress.fromMap(e.cast<String, dynamic>()))
          .toList(),
      ratingSum: (data['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  factory Rider.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) =>
      Rider.fromMap(snap.data(), snap.id);
}

/// A place a rider saved so they need not pin it again.
class SavedAddress {
  const SavedAddress({required this.label, required this.point, this.name});

  /// What the rider calls it — "Bahay", "Trabaho".
  final String label;

  /// The geocoded description, kept so the row is readable when the map is not.
  final String? name;

  final GeoPoint point;

  factory SavedAddress.fromMap(Map<String, dynamic> m) => SavedAddress(
        label: m['label'] as String? ?? '',
        name: m['name'] as String?,
        point: m['point'] is GeoPoint
            ? m['point'] as GeoPoint
            : const GeoPoint(0, 0),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'name': name,
        'point': point,
      };
}

/// Payloads for `riders/{uid}`, one builder per clause the rules allow.
///
/// Same shape as `RideWrites`: the client never assembles a map inline, so a
/// write can only ever contain keys some rule clause admits.
class RiderWrites {
  const RiderWrites._();

  /// Onboarding. `phone` comes from the verified Auth token rather than a
  /// form field — the rules require the two to match, so a rider cannot claim
  /// a number they did not prove they hold.
  static Map<String, dynamic> create({
    required String name,
    required String phone,
  }) =>
      {
        'name': name.trim(),
        'phone': phone,
        // Always null at creation. The photo is uploaded once the document
        // exists, so a failed upload cannot leave an orphan in the bucket.
        'profilePhotoUrl': null,
        'savedAddresses': const <Map<String, dynamic>>[],
        'ratingSum': 0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Renaming, and nothing else.
  ///
  /// The profile screen writes the name and the photo separately, because they
  /// complete at different moments — the name the instant Save is pressed, the
  /// photo only once an upload returns. Keeping `profilePhotoUrl` out of this
  /// payload is what stops a rename from touching a picture the rider did not
  /// mean to change.
  static Map<String, dynamic> updateName(String name) => {
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Editing name and photo together. Deliberately cannot touch `phone`, the
  /// rating counters, or `createdAt`.
  ///
  /// **Writes `profilePhotoUrl` unconditionally**, so omitting the argument
  /// CLEARS the rider's photo rather than leaving it alone. That is correct
  /// for a caller that genuinely holds both values and intends to set both;
  /// it is a trap for a caller that only wants to rename someone. Use
  /// [updateName] for that.
  static Map<String, dynamic> updateProfile({
    required String name,
    String? profilePhotoUrl,
  }) =>
      {
        'name': name.trim(),
        'profilePhotoUrl': profilePhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Sets or clears the photo URL on its own.
  ///
  /// Separate from [updateProfile] because the photo is written after the
  /// upload returns, which is a different moment from the rider pressing save.
  static Map<String, dynamic> setPhoto(String? url) => {
        'profilePhotoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Map<String, dynamic> saveAddresses(List<SavedAddress> addresses) => {
        'savedAddresses': addresses.map((a) => a.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
