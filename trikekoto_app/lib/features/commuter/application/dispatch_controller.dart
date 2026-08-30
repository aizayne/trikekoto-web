import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/providers.dart';
import '../../drivers/data/active_driver.dart';
import '../../rides/data/ride.dart';

/// The greedy nearest-driver search.
///
/// Runs on the commuter's device: fetch every available driver, sort by true
/// distance from the pickup point, and ping them one at a time. Each ping gets
/// [DispatchDefaults.offerTimeout]; if it lapses the search moves one step
/// deeper, up to [DispatchDefaults.maxDriversToTry] candidates, after which
/// the ride is marked expired.
///
/// State lives entirely in `rides/{id}.dispatch`, so nothing is lost if the
/// controller is torn down — and so a Cloud Function could take the loop over
/// later without touching the schema.
class DispatchController {
  DispatchController(this._ref);

  final Ref _ref;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot<Ride>>? _rideSub;

  /// Begins pinging drivers for [rideId]. Safe to call again; the previous
  /// loop is cancelled first.
  Future<void> start(String rideId) async {
    await stop();

    final refs = _ref.read(refsProvider);
    final config = _ref.read(dispatchConfigProvider);

    // Drive the first offer immediately rather than waiting a full timeout —
    // the commuter is staring at a spinner.
    await _sweep(rideId);

    _timer = Timer.periodic(config.offerTimeout, (_) async {
      await _sweep(rideId);
    });

    // Stop as soon as somebody accepts, or the ride ends.
    _rideSub = refs.ride(rideId).snapshots().listen((snap) {
      final ride = snap.data();
      if (ride == null) return;
      if (ride.status != RideStatus.searching) stop();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _rideSub?.cancel();
    _rideSub = null;
  }

  /// One pass: re-read the ride, pick the nearest untried driver, offer to
  /// them. Re-reading rather than trusting cached state matters — the driver
  /// may have declined since the last tick, which rewrites `dispatch`.
  Future<void> _sweep(String rideId) async {
    final refs = _ref.read(refsProvider);

    final rideSnap = await refs.ride(rideId).get();
    final ride = rideSnap.data();
    if (ride == null || ride.status != RideStatus.searching) {
      await stop();
      return;
    }

    final config = _ref.read(dispatchConfigProvider);

    // An offer that has not expired yet still belongs to its driver.
    if (ride.dispatch.hasLiveOffer) return;

    if (ride.dispatch.depth >= config.maxDriversToTry) {
      await refs
          .ride(rideId)
          .update(RideWrites.cancelByCommuter(exhausted: true));
      await stop();
      return;
    }

    final pickup = ride.pickup.geopoint;
    if (pickup == null) return;

    final candidate = await _nearestUntried(
      pickup: pickup,
      excluded: ride.dispatch.attemptedDrivers,
      radiusKm: config.searchRadiusKm,
    );

    if (candidate == null) {
      // Nobody available right now. Keep the loop alive — a driver may come
      // online before the attempt budget runs out.
      return;
    }

    await refs
        .ride(rideId)
        .update(RideWrites.offerTo(ride.dispatch.offerTo(candidate.email)));
  }

  Future<ActiveDriver?> _nearestUntried({
    required GeoPoint pickup,
    required List<String> excluded,
    required double radiusKm,
  }) async {
    final refs = _ref.read(refsProvider);
    final snap = await refs.availableDrivers.get();

    final candidates = snap.docs
        .map((d) => d.data())
        .where((d) => d.hasPosition)
        .where((d) => !excluded.contains(d.email))
        .map((d) => (
              driver: d,
              km: distanceKmBetween(pickup, d.geopoint),
            ))
        .where((c) => c.km <= radiusKm)
        .toList()
      ..sort((a, b) => a.km.compareTo(b.km));

    return candidates.isEmpty ? null : candidates.first.driver;
  }
}

final dispatchControllerProvider = Provider<DispatchController>((ref) {
  final controller = DispatchController(ref);
  ref.onDispose(controller.stop);
  return controller;
});

/// The commuter's current ride, if any. `limit(1)` on their own rides ordered
/// newest-first — the read rule admits it because `commuterUid` is theirs.
final myActiveRideProvider = StreamProvider<Ride?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return ref
      .watch(refsProvider)
      .ridesForCommuter(uid)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());
});
