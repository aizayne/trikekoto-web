import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../rides/data/ride.dart';

/// Keeps the commuter's search moving while their app is open.
///
/// The match itself no longer happens here. It used to: this controller read
/// every online driver's live position, ranked them by road distance, and
/// wrote the offer. That worked, and it was the wrong place for it — ranking
/// drivers requires reading the whole fleet's whereabouts, so any client that
/// could dispatch could also track. The rules had to leave `active_drivers`
/// readable by every signed-in account for the app to function at all.
///
/// So the ranking moved to `requestDispatch`, and what is left here is a
/// heartbeat: ask the server to advance this ride, wait one offer timeout,
/// ask again, and stop as soon as the ride leaves `searching`.
///
/// The schedule on the server does the same work every minute regardless.
/// This exists only for latency — a commuter who has just booked should not
/// watch a spinner for up to sixty seconds before the first driver is even
/// asked. Everything this does, the sweep would eventually do anyway, which
/// is what makes it safe for it to simply give up on error.
class DispatchController {
  DispatchController(this._ref);

  final Ref _ref;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot<Ride>>? _rideSub;

  /// Begins asking for [rideId] to be advanced. Safe to call again; the
  /// previous loop is cancelled first.
  Future<void> start(String rideId) async {
    await stop();

    final refs = _ref.read(refsProvider);
    final config = _ref.read(dispatchConfigProvider);

    // Ask immediately rather than waiting a full timeout — the commuter is
    // staring at a spinner.
    await _tick(rideId);

    _timer = Timer.periodic(config.offerTimeout, (_) async {
      await _tick(rideId);
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

  /// One request. The reply is an outcome word — never a driver, a distance,
  /// or a count of who is nearby.
  Future<void> _tick(String rideId) async {
    try {
      final result = await _ref
          .read(dispatchCallableProvider)
          .call<Map<String, dynamic>>({'rideId': rideId});

      // `expired` means the server closed the ride; `skipped` means it is no
      // longer searching. Either way there is nothing left to ask for, and
      // the ride subscription is about to tear this down regardless.
      final outcome = result.data['outcome'];
      if (outcome == 'expired' || outcome == 'skipped') await stop();
    } on FirebaseFunctionsException catch (e) {
      // A ride that is not ours, or a signed-out session: retrying cannot
      // fix either, and a timer that keeps calling would be a hot loop
      // against a function that will keep refusing.
      if (e.code == 'not-found' ||
          e.code == 'unauthenticated' ||
          e.code == 'invalid-argument') {
        debugPrint('Dispatch refused for $rideId: ${e.code}');
        await stop();
        return;
      }
      // Anything else — a cold start, a dropped connection, a rate limit —
      // is transient. Keep the timer; the next tick may well succeed, and
      // the server sweep is advancing the ride either way.
      debugPrint('Dispatch tick failed: ${e.code}');
    } catch (e) {
      debugPrint('Dispatch tick failed: $e');
    }
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
