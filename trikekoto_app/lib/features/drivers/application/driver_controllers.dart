import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Why going online failed, for the dashboard to put into words.
///
/// The controller has no BuildContext, so it names the failure and the screen
/// chooses the language.
enum PresenceFailure {
  locationOff,
  permissionDenied,
  permissionBlocked,
  noFix,
  refused,
  writeFailed,
}

class PresenceException implements Exception {
  const PresenceException(this.failure);

  final PresenceFailure failure;

  @override
  String toString() => 'PresenceException(${failure.name})';
}

/// Exactly which write failed, and the code the server gave.
///
/// Exists because "the switch turned on then went back off" was all a driver
/// could report, and nothing on the phone said why. The dashboard keeps this
/// on screen under the switch until the next attempt.
class PresenceIssue {
  const PresenceIssue({required this.write, required this.code});

  /// `presence` (active_drivers) or `ride` (the live ride's driver location).
  final String write;

  /// The Firebase error code, e.g. `permission-denied` or `unavailable`.
  final String code;

  @override
  String toString() => '$write: $code';
}

/// A failed write inside a ping, naming which write it was.
class PresenceWriteException implements Exception {
  const PresenceWriteException(this.issue, this.cause);

  final PresenceIssue issue;
  final Object cause;

  @override
  String toString() => 'PresenceWriteException($issue): $cause';
}

class PresenceStatus {
  const PresenceStatus({this.connecting = false, this.issue});

  /// Between the tap and the first accepted write. The switch is disabled and
  /// shows a spinner for this long.
  final bool connecting;

  /// The last failure, kept until the next attempt or going offline.
  final PresenceIssue? issue;
}

class PresenceStatusController extends Notifier<PresenceStatus> {
  @override
  PresenceStatus build() => const PresenceStatus();

  void connecting() => state = const PresenceStatus(connecting: true);

  /// Ends a connecting phase without discarding a failure recorded during it.
  void settled() => state = PresenceStatus(issue: state.issue);

  void failed(PresenceIssue issue) => state = PresenceStatus(issue: issue);

  void clear() => state = const PresenceStatus();
}

final presenceStatusProvider =
    NotifierProvider<PresenceStatusController, PresenceStatus>(
        PresenceStatusController.new);

/// Owns the driver's online presence and the GPS stream.
///
/// While online it writes `active_drivers/{email}`, which is what the greedy
/// search reads. While on a ride it *also* mirrors position onto the ride
/// document, which is how the commuter tracks the trike without ever being
/// able to read the driver index.
class PresenceController extends Notifier<bool> {
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<String>? _tokenSub;

  /// Filled in by push registration after going online, and kept current by
  /// token refreshes. Read on every ping.
  String? _pushToken;

  @override
  bool build() {
    ref.onDispose(() {
      _gpsSub?.cancel();
      _tokenSub?.cancel();
    });
    return false;
  }

  /// Goes online only once the server has accepted this driver's position.
  ///
  /// The order is the fix. The previous version turned the switch on, started
  /// the GPS stream, and only then made its first write — so the stream's own
  /// write could be refused first and switch the driver off, after which the
  /// first write saw "offline", skipped itself, and the refusal was never
  /// reported. A driver saw the switch come on and go back off, and nothing
  /// else. Now: location, a position, one awaited write, and only then the
  /// switch, the stream, and push.
  Future<void> goOnline() async {
    final status = ref.read(presenceStatusProvider.notifier);
    // One attempt at a time. Without this a second tap during the wait began
    // a second attempt, and a slide after the switch flipped sent goOffline.
    if (state || ref.read(presenceStatusProvider).connecting) return;
    status.connecting();

    try {
      await _ensureLocation();
      final pos = await _firstFix();

      // _publish will not write while offline, so the flag goes up first and
      // comes straight back down if the write fails.
      state = true;
      try {
        await _publish(pos);
      } on PresenceWriteException catch (e) {
        await _stop();
        status.failed(e.issue);
        throw PresenceException(e.issue.code == 'permission-denied'
            ? PresenceFailure.refused
            : PresenceFailure.writeFailed);
      }

      _startStream();
      status.clear();
      // Not awaited. Being online does not need push, so push must not be able
      // to delay it or block it — waiting on the token is what hung the switch.
      unawaited(_registerPush());
    } finally {
      if (ref.read(presenceStatusProvider).connecting) status.settled();
    }
  }

  /// A position to go online with: a fresh fix, or the last one the phone
  /// knows while a cold GPS warms up indoors.
  Future<Position> _firstFix() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            // Browsers have no "last known position" call, and geolocator_web
            // throws UnsupportedError for getLastKnownPosition. The browser's
            // equivalent is maximumAge: accept a position it already holds
            // from the last few minutes rather than waiting for a fresh one.
            ? WebSettings(
                accuracy: LocationAccuracy.high,
                maximumAge: const Duration(minutes: 5),
                timeLimit: const Duration(seconds: 20),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 20),
              ),
      );
    } on TimeoutException {
      // On web the cached position was already accepted above, so there is
      // nothing left to fall back to — and calling getLastKnownPosition there
      // would throw instead of reporting "no fix".
      if (kIsWeb) throw const PresenceException(PresenceFailure.noFix);
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const PresenceException(PresenceFailure.noFix);
    }
  }

  void _startStream() {
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
  }

  /// Asks for notification permission and a token, after the driver is
  /// already online, and attaches the token to presence when it arrives.
  ///
  /// Talks to the push service directly rather than through fcmTokenProvider:
  /// a one-off read of that provider is not guaranteed to deliver, and this
  /// path must not depend on one.
  Future<void> _registerPush() async {
    final push = ref.read(pushServiceProvider);
    final token = await tokenOrNull(push.registerForOffers(),
        limit: const Duration(seconds: 30));
    if (token == null || !state) return;
    _pushToken = token;
    _tokenSub?.cancel();
    _tokenSub = push.tokenRefreshes.listen((t) => _pushToken = t);

    final email = ref.read(driverEmailProvider);
    if (email.isEmpty) return;
    try {
      // updatedAt rides along: the presence rule validates the whole merged
      // document, and it requires updatedAt to equal request.time.
      await ref.read(refsProvider).activeDriver(email).update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      await CrashReporter.recordNonFatal(e, s, context: 'presence push token');
    }
  }

  /// A ping after the driver is online. A refusal turns the switch off and
  /// leaves the reason on screen under it; anything transient waits for the
  /// next ping.
  Future<void> _onPingFailed(Object e, StackTrace s) async {
    await CrashReporter.recordNonFatal(e, s, context: 'presence ping');
    if (e is PresenceWriteException && e.issue.code == 'permission-denied') {
      await _stop();
      ref.read(presenceStatusProvider.notifier).failed(e.issue);
    }
  }

  /// Offline without deleting presence: for when the write that failed was the
  /// one that would have created it, so there is nothing to delete.
  Future<void> _stop() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _tokenSub?.cancel();
    _tokenSub = null;
    state = false;
  }

  Future<void> goOffline() async {
    ref.read(presenceStatusProvider.notifier).clear();
    await _stop();

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

    try {
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
            fcmToken: _pushToken,
          ));
    } on FirebaseException catch (e) {
      throw PresenceWriteException(
          PresenceIssue(write: 'presence', code: e.code), e);
    }

    if (activeRide != null && activeRide.status.isLive) {
      try {
        await ref.read(refsProvider).ride(activeRide.id).update(
              RideWrites.locationPing(GeoPoint(pos.latitude, pos.longitude)),
            );
      } on FirebaseException catch (e) {
        throw PresenceWriteException(
            PresenceIssue(write: 'ride', code: e.code), e);
      }
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
