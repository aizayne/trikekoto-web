import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../firestore/collection_paths.dart';
import '../geo/geo_utils.dart';
import '../providers.dart';

/// Dispatch tuning, read from `config/app`.
///
/// These were compile-time constants, which meant re-tariffing or widening a
/// chapter's search radius required a new APK — and the APK reaches drivers
/// by QR code over Wi-Fi, not an update channel. As configuration they can
/// change while drivers are mid-shift.
class DispatchConfig {
  const DispatchConfig({
    this.searchRadiusKm = DispatchDefaults.searchRadiusKm,
    this.offerTimeout = DispatchDefaults.offerTimeout,
    this.maxDriversToTry = DispatchDefaults.maxDriversToTry,
  });

  final double searchRadiusKm;
  final Duration offerTimeout;
  final int maxDriversToTry;

  factory DispatchConfig.fromMap(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    const fallback = DispatchConfig();

    final seconds = (d['offerTimeoutSeconds'] as num?)?.toInt();
    return DispatchConfig(
      searchRadiusKm:
          (d['searchRadiusKm'] as num?)?.toDouble() ?? fallback.searchRadiusKm,
      offerTimeout: seconds == null || seconds <= 0
          ? fallback.offerTimeout
          : Duration(seconds: seconds),
      // Hard ceiling, not a preference: the security rules reject a dispatch
      // depth above 10, so a larger value here would produce writes the
      // server refuses rather than a wider search.
      maxDriversToTry: ((d['maxDriversToTry'] as num?)?.toInt() ??
              fallback.maxDriversToTry)
          .clamp(1, DispatchDefaults.maxDriversToTry),
    );
  }

  Map<String, dynamic> toMap() => {
        'searchRadiusKm': searchRadiusKm,
        'offerTimeoutSeconds': offerTimeout.inSeconds,
        'maxDriversToTry': maxDriversToTry,
      };
}

/// The area a chapter actually serves, as a centre and a radius.
///
/// **It warns; it does not refuse.** A resettlement's tricycles do leave the
/// resettlement — the highway, the hospital, the market in the next barangay
/// are all trips they take — so a booking outside the circle is flagged and
/// allowed through. A fence would turn the most useful rides into errors.
///
/// Off until a chapter sets it. The radius starts at zero, and zero means no
/// warning at all: a default centre guessed from a map would warn on every
/// legitimate booking in a chapter that sits somewhere else, which teaches
/// people to ignore warnings.
class ServiceArea {
  const ServiceArea({
    required this.label,
    required this.center,
    required this.radiusKm,
  });

  /// What the area is called, in the warning: "outside Balaybay Resettlement".
  final String label;
  final GeoPoint center;

  /// Zero turns the warning off.
  final double radiusKm;

  bool get warns => radiusKm > 0;

  bool covers(GeoPoint p) =>
      !warns || distanceKmBetween(center, p) <= radiusKm;

  bool coversPoint(LatLng p) =>
      !warns ||
      haversineKm(center.latitude, center.longitude, p.latitude, p.longitude) <=
          radiusKm;

  /// The chapter this was built for, as a starting point for the map picker.
  /// Nothing warns until an admin sets a radius.
  static const fallback = ServiceArea(
    label: 'Balaybay Resettlement',
    center: GeoPoint(14.9747, 120.1577),
    radiusKm: 0,
  );

  factory ServiceArea.fromMap(Object? value) {
    final m = value is Map ? value : const <String, dynamic>{};
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    final label = (m['label'] as String?)?.trim();
    return ServiceArea(
      label: label == null || label.isEmpty ? fallback.label : label,
      center: lat == null || lng == null
          ? fallback.center
          : GeoPoint(lat, lng),
      // Negative or absurd values read as "off" rather than as a tiny circle
      // that warns on everything.
      radiusKm: ((m['radiusKm'] as num?)?.toDouble() ?? 0).clamp(0, 100),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'lat': center.latitude,
        'lng': center.longitude,
        'radiusKm': radiusKm,
      };
}

final serviceAreaProvider = Provider<ServiceArea>((ref) {
  return ServiceArea.fromMap(ref.watch(appConfigProvider).value?['serviceArea']);
});

/// The raw `config/app` document, streamed.
///
/// A stream rather than a one-shot read so that an admin changing the search
/// radius takes effect on every running client immediately — that is the
/// entire point of holding these values server-side.
final appConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref
      .watch(refsProvider)
      .appConfig
      .snapshots()
      .map((snap) => snap.data() ?? const <String, dynamic>{})
      // A missing or unreadable document must not break booking; every
      // consumer falls back to the compiled defaults.
      .handleError((_) => const <String, dynamic>{});
});

/// Whether new bookings are being accepted.
///
/// The pilot stop button. Enforced by the security rules, not here — this
/// provider only decides what the admin panel shows. A modified client cannot
/// book while it is false, because the server refuses the write.
///
/// Absent means open: a project that has not seeded `config/app` must still
/// work, and a missing flag should never read as "stopped".
final acceptingRidesProvider = Provider<bool>((ref) {
  final doc = ref.watch(appConfigProvider).value;
  return doc?['acceptingRides'] as bool? ?? true;
});

final dispatchConfigProvider = Provider<DispatchConfig>((ref) {
  return DispatchConfig.fromMap(ref.watch(appConfigProvider).value);
});

/// Where road routing is fetched from.
///
/// Defaults to the public OSRM demo server, which is rate-limited and whose
/// usage policy covers development only. Point this at a self-hosted instance
/// before a real pilot — it is configuration precisely so that does not need
/// an app release.
const kDefaultRoutingBaseUrl = 'https://router.project-osrm.org';

final routingBaseUrlProvider = Provider<String>((ref) {
  final raw = ref.watch(appConfigProvider).value?['routingBaseUrl'];
  final url = raw is String ? raw.trim() : '';
  // Rejects a blank or non-HTTPS value rather than issuing requests against
  // whatever ends up in the document.
  return url.startsWith('https://') ? url : kDefaultRoutingBaseUrl;
});

/// The full document as an admin edits it, defaults included.
///
/// Fares were removed from the app: TODA tariffs are set by ordinance and
/// posted at the terminal, and a second number on a phone could only ever
/// disagree with the official one.
Map<String, dynamic> configDocumentFrom(DispatchConfig dispatch) =>
    dispatch.toMap();
