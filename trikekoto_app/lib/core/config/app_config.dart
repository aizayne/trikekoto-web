import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fare/fare_calculator.dart';
import '../firestore/collection_paths.dart';
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

final fareConfigProvider = Provider<FareConfig>((ref) {
  return FareConfig.fromMap(ref.watch(appConfigProvider).value);
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
Map<String, dynamic> configDocumentFrom(
  DispatchConfig dispatch,
  FareConfig fare,
) =>
    {...dispatch.toMap(), ...fare.toMap()};
