import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../data/rider.dart';

/// The commuter's own position, for showing them on the map beside the driver.
///
/// **Never leaves the device.** Nothing here writes to Firestore, and nothing
/// reads it but the map widget. The driver already has the pickup point they
/// agreed to; streaming a passenger's live position to the server would add a
/// standing record of where someone is, for no operational gain — and
/// commuters are anonymous by design precisely so no such record exists.
///
/// That also means this costs nothing: no writes, no reads, no rules change.
///
/// Permission is *not* requested here. A commuter who has never granted
/// location still books by panning the map, and a permission dialog that
/// appears unbidden while they are watching for their driver is worse than an
/// absent dot. The picker asks when they tap my-location; if they said yes
/// there, this works from then on.
final commuterPositionProvider = StreamProvider.autoDispose<LatLng?>((ref) async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    yield null;
    return;
  }

  final permission = await Geolocator.checkPermission();
  final granted = permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
  if (!granted) {
    yield null;
    return;
  }

  // A last known fix appears instantly; the stream then corrects it. Without
  // this the dot is missing for the first few seconds, which reads as broken
  // rather than as waiting.
  final last = await Geolocator.getLastKnownPosition();
  if (last != null) yield LatLng(last.latitude, last.longitude);

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      // Coarser than the driver's 50 m. A passenger is standing still or
      // sitting in the trike; their dot does not need to be precise, it needs
      // to answer "roughly where am I relative to the driver".
      distanceFilter: 25,
    ),
  ).map((p) => LatLng(p.latitude, p.longitude));
});


/// The signed-in rider's own profile, or null when they have no account.
///
/// Anonymous commuters — still the default path — have no `riders/{uid}`
/// document, and the rules refuse the read for anyone else's. A denial here
/// therefore means "no account", not "something broke", so it degrades to null
/// rather than surfacing an error on a screen that works fine without it.
final myRiderProfileProvider = StreamProvider<Rider?>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return ref
      .watch(refsProvider)
      .rider(uid)
      .snapshots()
      .map((snap) => snap.exists ? Rider.fromSnapshot(snap) : null)
      .handleError((_) {})
      .cast<Rider?>();
});
