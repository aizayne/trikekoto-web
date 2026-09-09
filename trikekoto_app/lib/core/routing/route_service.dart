import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../geo/geo_utils.dart';

/// A road route between two points.
class TripRoute {
  const TripRoute({
    required this.distanceKm,
    required this.duration,
    required this.geometry,
    required this.isRouted,
  });

  final double distanceKm;
  final Duration duration;

  /// The road path, for drawing on the map. Empty for a fallback estimate.
  final List<LatLng> geometry;

  /// False when this is a straight-line fallback rather than a real route.
  /// The UI says so, because a fare quoted from a fallback is a floor.
  final bool isRouted;

  /// Straight-line estimate, used when routing is unavailable.
  ///
  /// A road trip is always at least as long as the crow-flies distance, so a
  /// fallback quote under-reads. The 1.3 factor is a conventional detour
  /// allowance for a street grid — it does not make the number accurate, it
  /// stops it being obviously low. Flagged via [isRouted] either way, so the
  /// UI can say the fare is an estimate rather than a quote.
  factory TripRoute.straightLine(GeoPoint from, GeoPoint to) {
    final km = distanceKmBetween(from, to) * 1.3;
    return TripRoute(
      distanceKm: km,
      // ~15 km/h is a realistic tricycle average through barangay streets.
      duration: Duration(minutes: (km / 15 * 60).round()),
      geometry: const [],
      isRouted: false,
    );
  }
}

/// Road routing via OSRM.
///
/// OSRM is used rather than a commercial routing API for the same reason the
/// map is OpenStreetMap: no per-request billing, which was an explicit
/// constraint on this project.
///
/// > **The public demo server is not for production.** `router.project-osrm.org`
/// > is rate-limited and its usage policy covers development only. Point
/// > `routingBaseUrl` in `config/app` at a self-hosted OSRM instance before a
/// > real pilot — the editor already exposes it, and no code change is needed.
class RouteService {
  RouteService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _userAgent = 'ph.trikekoto.trikekoto_app';
  static const _timeout = Duration(seconds: 8);

  /// Fetches the driving route, falling back to a straight line on any
  /// failure — no network, a rate limit, a malformed reply, or a pair of
  /// points OSRM cannot connect.
  ///
  /// Booking must never be blocked by a routing outage, so this returns a
  /// usable answer in every case rather than throwing.
  Future<TripRoute> between(GeoPoint from, GeoPoint to) async {
    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=polyline',
    );

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Routing HTTP ${response.statusCode}; using straight line');
        return TripRoute.straightLine(from, to);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        debugPrint('Routing returned ${body['code']}; using straight line');
        return TripRoute.straightLine(from, to);
      }

      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return TripRoute.straightLine(from, to);
      }

      final route = routes.first as Map<String, dynamic>;
      final metres = (route['distance'] as num).toDouble();
      final seconds = (route['duration'] as num).toDouble();

      return TripRoute(
        distanceKm: metres / 1000,
        duration: Duration(seconds: seconds.round()),
        geometry: decodePolyline(route['geometry'] as String? ?? ''),
        isRouted: true,
      );
    } catch (e) {
      debugPrint('Routing unavailable ($e); using straight line');
      return TripRoute.straightLine(from, to);
    }
  }

  /// Road distance in kilometres from [origin] to each of [destinations],
  /// returned in the same order.
  ///
  /// One request for the whole set, via OSRM's table service. Asking
  /// `/route` per driver would multiply the request rate by the number of
  /// candidates and get the app throttled long before it got accurate.
  ///
  /// Returns `null` when the whole lookup is unusable — no network, a rate
  /// limit, a server without distance annotations. An individual entry is
  /// null when that one driver cannot be reached by road from the pickup,
  /// which is a real answer rather than a failure: an unreachable driver
  /// should not be offered the ride at all.
  ///
  /// The caller must be able to proceed without this. Dispatch is not
  /// allowed to stall because a routing server is down.
  Future<List<double?>?> roadDistancesKm(
    GeoPoint origin,
    List<GeoPoint> destinations,
  ) async {
    if (destinations.isEmpty) return const [];

    final coords = [origin, ...destinations]
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    // sources=0 asks for one row — origin to everything — instead of the
    // full N×N matrix nothing here would read.
    final uri = Uri.parse(
      '$baseUrl/table/v1/driving/$coords?sources=0&annotations=distance',
    );

    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Table HTTP ${response.statusCode}; ranking by straight line');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') {
        debugPrint('Table returned ${body['code']}; ranking by straight line');
        return null;
      }

      // `distances` is absent on an OSRM built without the distance
      // annotation. Durations would still be present, but silently ranking
      // by a different metric than the one asked for is worse than falling
      // back to something the caller already understands.
      final matrix = body['distances'] as List?;
      if (matrix == null || matrix.isEmpty) return null;

      final row = matrix.first as List?;
      // Row is origin→[origin, ...destinations], so it is one longer.
      if (row == null || row.length != destinations.length + 1) return null;

      return [
        for (var i = 1; i < row.length; i++)
          row[i] == null ? null : (row[i] as num).toDouble() / 1000,
      ];
    } catch (e) {
      debugPrint('Table unavailable ($e); ranking by straight line');
      return null;
    }
  }
}

/// Decodes Google's encoded-polyline format, which OSRM emits at precision 5.
///
/// Written out rather than pulled in as a dependency: it is thirty lines, and
/// the map layer already carries enough third-party surface.
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  if (encoded.isEmpty) return const [];

  final points = <LatLng>[];
  final factor = math.pow(10, precision).toDouble();
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    int result = 0, shift = 0, byte;

    do {
      if (index >= encoded.length) return points;
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    result = 0;
    shift = 0;
    do {
      if (index >= encoded.length) return points;
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / factor, lng / factor));
  }

  return points;
}

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(baseUrl: ref.watch(routingBaseUrlProvider));
});
