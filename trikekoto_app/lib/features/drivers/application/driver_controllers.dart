import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
/// Why going online failed, for the dashboard to put into words.
///
/// The controller has no BuildContext, so it names the failure and the screen
/// chooses the language. The old `Exception('Location permission denied')`
/// reached a Filipino-speaking driver in English, and a server refusal read
/// as "You may not be approved yet" whatever the actual reason.
enum PresenceFailure { locationOff, permissionDenied, permissionBlocked, refused }

class PresenceException implements Exception {
  const PresenceException(this.failure);

  final PresenceFailure failure;

  @override
  String toString() => 'PresenceException(${failure.name})';
}

/// How long going online waits for a push token before carrying on without.
const pushTokenWait = Duration(seconds: 6);

/// A push token if one arrives in time, otherwise null — never a hang.
///
/// Push is not required to be online: offers still reach an open dashboard.
/// So a token request that fails, or never finishes, may cost a driver a few
/// seconds and must not cost them the shift.
Future<String?> tokenOrNull(
  Future<String?> token, {
  Duration limit = pushTokenWait,
}) =>
    token
        .timeout(limit, onTimeout: () => null)
        .catchError((Object _) => null);

class PresenceController extends Notifier<bool> {
  StreamSubscription<Position>? _gpsSub;

  @override
  bool build() {
    ref.onDispose(() => _gpsSub?.cancel());
    return false;
  }

  Future<void> goOnline() async {
    // Throws a PresenceException the dashboard can put into words: phone
    // location off, permission refused, or permission blocked for good.
    await _ensureLocation();

    // Registered on going online rather than at launch: the notification
    // prompt then arrives attached to an action the driver just took, which
    // is the moment it makes sense. Declining is not fatal — in-app offers
    // still arrive while the dashboard is open.
    //
    // Bounded. This used to await the token with no limit, and catchError
    // only handles a failure — a request that never finishes is not one. A
    // stuck token request left the switch off with no message at all, the
    // worst way to fail: the driver cannot tell that anything is wrong.
    await tokenOrNull(ref.read(fcmTokenProvider.future));

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
    ).listen(
      // An async listener's failure never reaches onError — it escapes as an
      // uncaught error — so each ping handles its own.
      (pos) => _publish(pos)
          .catchError((Object e, StackTrace s) => _onPingFailed(e, s)),
      onError: (Object e, StackTrace s) =>
          CrashReporter.recordNonFatal(e, s, context: 'gps stream'),
    );

    // Publish once immediately so the driver appears without having to move,
    // and so a refusal is found now — while the driver is looking at the
    // switch — rather than never.
    final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      // No fix yet: indoors, or a cold GPS. Stay online; the stream publishes
      // as soon as a position arrives.
      return;
    }

    try {
      await _publish(pos);
    } on FirebaseException catch (e) {
      // Anything but a refusal is transient, and the stream retries it.
      if (e.code != 'permission-denied') return;
      // The server refused presence — for a driver, almost always an ID not
      // yet approved. Leaving the switch on over a refusal would show a
      // driver as on shift whom no commuter can ever be offered.
      await _stop();
      throw const PresenceException(PresenceFailure.refused);
    }
  }

  /// A ping after the driver is already online. Nobody is watching the switch
  /// by then, so a refusal turns it off — visibly offline beats invisibly
  /// offline — and anything transient simply waits for the next ping.
  Future<void> _onPingFailed(Object e, StackTrace s) async {
    if (e is FirebaseException && e.code == 'permission-denied') {
      await _stop();
    }
    await CrashReporter.recordNonFatal(e, s, context: 'presence ping');
  }

  /// Offline without deleting presence: for when the write that failed was the
  /// one that would have created it, so there is nothing to delete.
  Future<void> _stop() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    state = false;
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

  Future<void> _ensureLocation() async {
    // Checked first. With location services off the permission check still
    // passes, and the driver would be "online" at no position at all.
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PresenceException(PresenceFailure.locationOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // Android will not show the prompt again; only Settings can undo it,
      // so the message has to say Settings rather than "try again".
      throw const PresenceException(PresenceFailure.permissionBlocked);
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const PresenceException(PresenceFailure.permissionDenied);
    }
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

  /// Completes the ride.
  ///
  /// Records nothing about money or distance. The app does not quote fares:
  /// TODA tariffs are set by ordinance and posted at the terminal, and
  /// passengers pay the driver in cash.
  Future<void> complete(Ride ride) => _ref
      .read(refsProvider)
      .ride(ride.id)
      .update(RideWrites.complete());

  Future<void> cancel(Ride ride) => _ref
      .read(refsProvider)
      .ride(ride.id)
      .update(RideWrites.cancelByDriver());
}

final rideActionsProvider = Provider<RideActions>(RideActions.new);
