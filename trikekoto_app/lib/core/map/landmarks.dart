import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../firestore/collection_paths.dart';
import '../providers.dart';

/// A place the chapter has named on the map.
///
/// OpenStreetMap is thin in a barangay: the terminal, the sari-sari store on
/// the corner and the covered court people give directions by are often not on
/// it. These are the places commuters actually say, kept by the chapter's admin.
class Landmark {
  const Landmark({required this.id, required this.name, required this.point});

  final String id;
  final String name;
  final LatLng point;

  /// Null for a document with no usable point, so one bad row cannot fail the
  /// whole list.
  static Landmark? fromMap(String id, Map<String, dynamic>? data) {
    final name = (data?['name'] as String?)?.trim();
    final point = data?['point'];
    if (name == null || name.isEmpty || point is! GeoPoint) return null;
    return Landmark(
      id: id,
      name: name,
      point: LatLng(point.latitude, point.longitude),
    );
  }
}

/// Landmarks whose name matches [query], best first.
///
/// Runs on the phone, against a list it already holds, so it is safe to call
/// on every keystroke. Nominatim's policy forbids that, which is why OSM search
/// still waits for the commuter to submit.
///
/// A name starting with the query ranks above one merely containing it, then a
/// word starting with it, so "pa" finds "Palengke" before "Tapat ng Plaza".
List<Landmark> matchLandmarks(
  Iterable<Landmark> landmarks,
  String query, {
  int limit = 6,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  int? rank(Landmark l) {
    final name = l.name.toLowerCase();
    if (name.startsWith(q)) return 0;
    if (name.split(RegExp(r'\s+')).any((w) => w.startsWith(q))) return 1;
    if (name.contains(q)) return 2;
    return null;
  }

  final hits = [
    for (final l in landmarks)
      if (rank(l) case final r?) (r, l),
  ]..sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      return byRank != 0 ? byRank : a.$2.name.compareTo(b.$2.name);
    });
  return [for (final hit in hits.take(limit)) hit.$2];
}

/// Writing landmarks, for the admin screen. The rules admit admins only.
class LandmarkWrites {
  const LandmarkWrites._();

  static Map<String, dynamic> create({
    required String name,
    required LatLng point,
  }) =>
      {
        'name': name.trim(),
        'point': GeoPoint(point.latitude, point.longitude),
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// Every landmark, by name.
///
/// No retry, and failures read as an empty list where it is used. A map with no
/// landmarks still works, so this must never get in the way of picking a place.
final landmarksProvider = StreamProvider<List<Landmark>>(
  (ref) => ref
      .watch(firestoreProvider)
      .collection(FsCollections.landmarks)
      .orderBy('name')
      // A chapter's worth. Each one is a read every time the list loads.
      .limit(200)
      .snapshots()
      .map((s) => [
            for (final d in s.docs) ?Landmark.fromMap(d.id, d.data()),
          ]),
  retry: (_, _) => null,
);
