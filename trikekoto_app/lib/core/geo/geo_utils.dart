import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Great-circle distance in kilometres.
///
/// The greedy match sorts candidates by this. For a single TODA chapter the
/// straight-line distance is a good enough proxy for road distance, and it
/// costs nothing — a routing API call per candidate would not be.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double distanceKmBetween(GeoPoint a, GeoPoint b) =>
    haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);

double _toRadians(double degrees) => degrees * math.pi / 180.0;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Geohash encoder using the standard geofire/geoflutterfire alphabet.
///
/// Written on every presence update so radius queries by geohash prefix work
/// later without a migration, even though the current match does a full scan
/// of online drivers.
String encodeGeohash(double latitude, double longitude, {int precision = 9}) {
  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  final hash = StringBuffer();
  var bit = 0;
  var ch = 0;
  var even = true;

  while (hash.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (longitude > mid) {
        ch = (ch << 1) + 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude > mid) {
        ch = (ch << 1) + 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    even = !even;
    if (++bit == 5) {
      hash.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return hash.toString();
}
