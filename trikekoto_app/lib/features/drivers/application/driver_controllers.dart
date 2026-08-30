import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/fare/fare_calculator.dart';
import '../../../core/config/app_config.dart';
import '../../../core/diagnostics/crash_reporter.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/providers.dart';
import '../../rides/data/ride.dart';
import '../data/active_driver.dart';

/// The signed-in driver's normalised email, which is their document ID
/// everywhere in this schema.
final driverEmailProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  return normalizeEmail(user?.email);
});

/// Streams the driver's own profile so approval changes made by an admin land
/// on the dashboard without a sign-out.
final myDriverProfileProvider = StreamProvider((ref) {
  final email = ref.watch(driverEmailProvider);
  if (email.isEmpty) return const Stream.empty();
  return ref.watch(refsProvider).driver(email).snapshots().map((s) => s.data());
});

/// Rides currently offered to this driver by some commuter's greedy sweep.
final myOffersProvider = StreamProvider<List<Ride>>((ref) {
  final email = ref.watch(driverEmailProvider);
  if (email.isEmpty) return Stream.value(const []);
  return ref
      .watch(refsProvider)
      .offersFor(email)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

/// The ride this driver is currently running, if any.
final myActiveRideProvider = StreamProvider<Ride?>((ref) {
  final email = ref.watch(driverEmailProvider);
  if (email.isEmpty) return Stream.value(null);
  return ref
      .watch(refsProvider)
      .activeRideFor(email)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : s.docs.first.data());
});

/// Owns the driver's online presence and the GPS stream.
///
/// While online it writes `active_drivers/{email}`, which is what the greedy
/// search reads. While on a ride it *also* mirrors position onto the ride
/// document, which is how the commuter tracks the trike without ever being
/// able to read the driver index.
class PresenceController extends Notifier<bool> {
  StreamSubscription<Position>? _gpsSub;

  @override
  bool build() {
    ref.onDispose(() => _gpsSub?.cancel());
    return false;
  }

  Future<void> goOnline() async {
    final permission = await _ensurePermission();
    if (!permission) throw Exception('Location permission denied');

    // Registered on going online rather than at launch: the notification
    // prompt then arrives attached to an action the driver just took, which
    // is the moment it makes sense. Declining is not fatal — in-app offers
    // still arrive while the dashboard is open.
    await ref.read(fcmTokenProvider.future).catchError((_) => null);

    state = true;
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Only emit after real movement — every emission is a Firestore
        // write, and a parked trike should not bill for one every second.
        //
        // 50 m, not 20 m. Presence writes are 93.5% of everything this system
        // writes, and at 15 km/h a 50 m filter still refreshes a driver's
        // position every ~12 s — finer than the 15 s dispatch cadence
        // actually consumes. The precision at 20 m was paid for and thrown
        // away; widening it cuts total writes 2.5×.
        // See COST_AND_PERFORMANCE.md.
        distanceFilter: 50,
      ),
    ).listen(_publish, onError: (_) {});

    // Publish once immediately so the driver appears without having to move.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _publish(pos);
    } catch (_) {
      // The stream will catch up.
    }
  }

  Future<void> goOffline() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    state = false;

    final email = ref.read(driverEmailProvider);
    if (email.isEmpty) return;
    try {
      await ref.read(refsProvider).activeDriver(email).delete();
    } catch (_) {
      // Nothing to clean up.
    }
  }

  Future<void> _publish(Position pos) async {
    final email = ref.read(driverEmailProvider);
    if (email.isEmpty || !state) return;

    final activeRide = ref.read(myActiveRideProvider).value;

    await ref
        .read(firestoreProvider)
        .collection(FsCollections.activeDrivers)
        .doc(email)
        .set(ActiveDriver.presencePayload(
          email: email,
          isOnline: true,
          availability: activeRide == null
              ? DriverAvailability.idle
              : DriverAvailability.onRide,
          latitude: pos.latitude,
          longitude: pos.longitude,
          geohash: encodeGeohash(pos.latitude, pos.longitude),
          accuracy: pos.accuracy,
          heading: pos.heading,
          speed: pos.speed,
          currentRideId: activeRide?.id,
          // Carried on every ping so a rotated token self-heals on the next
          // GPS update rather than leaving the driver unreachable.
          fcmToken: ref.read(fcmTokenProvider).value,
        ));

    if (activeRide != null && activeRide.status.isLive) {
      await ref.read(refsProvider).ride(activeRide.id).update(
            RideWrites.locationPing(GeoPoint(pos.latitude, pos.longitude)),
          );
    }
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}

final presenceProvider =
    NotifierProvider<PresenceController, bool>(PresenceController.new);

/// Ride actions available to a driver.
class RideActions {
  const RideActions(this._ref);

  final Ref _ref;

  /// Accepts an offer inside a transaction.
  ///
  /// The transaction settles the race between two drivers tapping at the same
  /// instant; the security rule independently requires the pre-image to still
  /// be unassigned, so neither mechanism is load-bearing on its own.
  ///
  /// Throws [StateError] when the ride was taken first, so the UI can say so
  /// rather than showing a raw permission error.
  Future<void> accept(Ride ride) async {
    final email = _ref.read(driverEmailProvider);
    final refs = _ref.read(refsProvider);
    final db = _ref.read(firestoreProvider);

    final profile = await refs.driver(email).get();
    final driver = profile.data();
    if (driver == null) throw StateError('Driver profile not found.');

    final position = await Geolocator.getLastKnownPosition();

    await db.runTransaction((tx) async {
      final rideRef = db.collection(FsCollections.rides).doc(ride.id);
      final fresh = await tx.get(rideRef);
      final data = fresh.data();

      if (data == null) throw StateError('That ride no longer exists.');
      if (data['status'] != RideStatus.searching.wire ||
          data['assignedDriver'] != null) {
        // A lost race is expected, not a fault — but the rate of it is worth
        // knowing, because a sudden rise means dispatch is offering one ride
        // to several drivers at once.
        CrashReporter.log('accept lost race on ride ${ride.id}');
        throw StateError('Another driver took that ride.');
      }

      tx.update(
        rideRef,
        RideWrites.accept(
          driverEmail: email,
          snapshot: RideDriverSnapshot(
            email: email,
            firstName: driver.firstName,
            phone: driver.phone,
            plateNumber: driver.plateNumber,
            ratingSum: driver.ratingSum,
            ratingCount: driver.ratingCount,
          ),
          driverLocation: position == null
              ? null
              : GeoPoint(position.latitude, position.longitude),
        ),
      );
    });
  }

  Future<void> decline(Ride ride) async {
    final email = _ref.read(driverEmailProvider);
    await _ref.read(refsProvider).ride(ride.id).update(
          RideWrites.decline(driverEmail: email, current: ride.dispatch),
        );
  }

  Future<void> start(Ride ride) =>
      _ref.read(refsProvider).ride(ride.id).update(RideWrites.startTrip());

  /// Completes the ride and records what it cost.
  ///
  /// Distance is straight-line from the pickup point to wherever the trike
  /// actually stopped, which under-reads against the road distance a
  /// passenger travels — a fare quoted from it is a floor, not a final
  /// price. Replace [_tripDistanceKm] with a routed distance once the
  /// mapping phase lands; nothing else here has to change.
  Future<void> complete(Ride ride) async {
    final distanceKm = await _tripDistanceKm(ride);
    final quote = distanceKm == null
        ? null
        : estimateFare(
            distanceKm: distanceKm,
            config: _ref.read(fareConfigProvider),
          );

    await _ref.read(refsProvider).ride(ride.id).update(
          RideWrites.complete(
            distanceKm: distanceKm,
            fareEstimate: quote?.total,
          ),
        );
  }

  /// Straight-line pickup-to-dropoff distance, or null when either endpoint
  /// is unknown — legacy rides carry no pickup coordinate, and a driver
  /// whose GPS never fixed has no endpoint. Completion must succeed either
  /// way, so the fare is simply omitted.
  Future<double?> _tripDistanceKm(Ride ride) async {
    final pickup = ride.pickup.geopoint;
    if (pickup == null) return null;

    GeoPoint? end = ride.driverLocation;
    if (end == null) {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        end = GeoPoint(position.latitude, position.longitude);
      }
    }
    if (end == null) return null;

    return distanceKmBetween(pickup, end);
  }

  Future<void> cancel(Ride ride) => _ref
      .read(refsProvider)
      .ride(ride.id)
      .update(RideWrites.cancelByDriver());
}

final rideActionsProvider = Provider<RideActions>(RideActions.new);
