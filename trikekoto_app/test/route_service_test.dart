import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trikekoto_app/core/geo/geo_utils.dart';
import 'package:trikekoto_app/core/routing/route_service.dart';

/// Tests for road routing.
///
/// The behaviour that matters most is not the happy path — it is that a
/// routing outage degrades to a usable estimate instead of blocking a
/// booking, and that the result says which of the two it is.

const _plaza = GeoPoint(14.5995, 120.9842);
const _palengke = GeoPoint(14.6042, 120.9887);

RouteService _serviceReturning(http.Response Function(http.Request) handler) =>
    RouteService(baseUrl: 'https://example.test', client: MockClient((r) async => handler(r)));

String _osrmBody({
  required double metres,
  required double seconds,
  String geometry = '',
}) =>
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {'distance': metres, 'duration': seconds, 'geometry': geometry},
      ],
    });

void main() {
  group('polyline decoding', () {
    test('decodes the reference example from the format spec', () {
      // The canonical test vector: (38.5,-120.2) (40.7,-120.95) (43.252,-126.453)
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 1e-5));
      expect(points[0].longitude, closeTo(-120.2, 1e-5));
      expect(points[2].latitude, closeTo(43.252, 1e-5));
      expect(points[2].longitude, closeTo(-126.453, 1e-5));
    });

    test('an empty string decodes to no points, not a crash', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('a truncated payload stops cleanly instead of throwing', () {
      // A cut-off response is a realistic outcome on a dropped connection.
      expect(() => decodePolyline('_p~iF~ps|U_ulL'), returnsNormally);
    });
  });

  group('routing', () {
    test('uses the road distance the service reports', () async {
      final service = _serviceReturning(
        (_) => http.Response(_osrmBody(metres: 4200, seconds: 900), 200),
      );

      final route = await service.between(_plaza, _palengke);

      expect(route.isRouted, isTrue);
      expect(route.distanceKm, closeTo(4.2, 1e-9));
      expect(route.duration, const Duration(minutes: 15));
    });

    test('sends the coordinates in OSRM order — longitude first', () async {
      late Uri captured;
      final service = _serviceReturning((request) {
        captured = request.url;
        return http.Response(_osrmBody(metres: 100, seconds: 60), 200);
      });

      await service.between(_plaza, _palengke);

      // Swapping these silently routes somewhere else entirely, and the
      // result still looks like a plausible distance.
      expect(captured.path, contains('120.9842,14.5995;120.9887,14.6042'));
    });

    test('falls back to a straight line on an HTTP error', () async {
      final service =
          _serviceReturning((_) => http.Response('rate limited', 429));

      final route = await service.between(_plaza, _palengke);

      expect(route.isRouted, isFalse);
      expect(route.distanceKm, greaterThan(0));
      expect(route.geometry, isEmpty);
    });

    test('falls back when OSRM cannot connect the points', () async {
      final service = _serviceReturning(
        (_) => http.Response(jsonEncode({'code': 'NoRoute'}), 200),
      );

      final route = await service.between(_plaza, _palengke);
      expect(route.isRouted, isFalse);
    });

    test('falls back on a malformed body rather than throwing', () async {
      final service = _serviceReturning((_) => http.Response('<html>', 200));

      final route = await service.between(_plaza, _palengke);
      expect(route.isRouted, isFalse);
    });

    test('falls back when the network is unreachable', () async {
      final service = RouteService(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      final route = await service.between(_plaza, _palengke);
      expect(route.isRouted, isFalse);
      expect(route.distanceKm, greaterThan(0));
    });
  });

  group('the distance table used to rank drivers', () {
    const driverA = GeoPoint(14.6001, 120.9850);
    const driverB = GeoPoint(14.6010, 120.9860);

    String tableBody(List<double?> metres) => jsonEncode({
          'code': 'Ok',
          // Row is origin→[origin, ...destinations], so a leading zero.
          'distances': [
            [0, ...metres],
          ],
        });

    test('returns one distance per destination, in kilometres and in order',
        () async {
      final service = _serviceReturning(
        (_) => http.Response(tableBody([1500, 800]), 200),
      );

      final km = await service.roadDistancesKm(_plaza, [driverA, driverB]);

      // Order is what the caller ranks by. Getting it right matters more
      // than the values: a shuffled row offers the ride to the wrong driver
      // while looking entirely plausible.
      expect(km, [1.5, 0.8]);
    });

    test('asks for one row, not the whole matrix', () async {
      late Uri captured;
      final service = _serviceReturning((request) {
        captured = request.url;
        return http.Response(tableBody([100, 200]), 200);
      });

      await service.roadDistancesKm(_plaza, [driverA, driverB]);

      // sources=0 is what keeps this O(n) instead of O(n²). Without it OSRM
      // computes every driver-to-driver pair, which nothing here reads.
      expect(captured.queryParameters['sources'], '0');
      expect(captured.queryParameters['annotations'], 'distance');
      expect(captured.path, contains('/table/v1/driving/'));
      // Longitude first, origin leading, same as the route endpoint.
      expect(captured.path, contains('120.9842,14.5995;120.985,14.6001'));
    });

    test('a driver with no road connection comes back null, not infinity',
        () async {
      // OSRM emits null for an unroutable pair. Coercing it to a huge number
      // would rank that driver last but still offerable, and an offer to
      // someone who cannot reach the pickup wastes a full timeout.
      final service = _serviceReturning(
        (_) => http.Response(tableBody([null, 900]), 200),
      );

      expect(await service.roadDistancesKm(_plaza, [driverA, driverB]),
          [null, 0.9]);
    });

    test('an empty destination list costs no request', () async {
      var called = false;
      final service = _serviceReturning((_) {
        called = true;
        return http.Response(tableBody([]), 200);
      });

      expect(await service.roadDistancesKm(_plaza, const []), isEmpty);
      expect(called, isFalse);
    });

    group('degrades to null so the caller keeps its straight-line order', () {
      test('on an HTTP error', () async {
        final service =
            _serviceReturning((_) => http.Response('rate limited', 429));
        expect(await service.roadDistancesKm(_plaza, [driverA]), isNull);
      });

      test('when OSRM reports a non-Ok code', () async {
        final service = _serviceReturning(
          (_) => http.Response(jsonEncode({'code': 'NoTable'}), 200),
        );
        expect(await service.roadDistancesKm(_plaza, [driverA]), isNull);
      });

      test('on a server built without distance annotations', () async {
        // Durations would still be present. Ranking by a different metric
        // than the one asked for, silently, is worse than not ranking.
        final service = _serviceReturning(
          (_) => http.Response(
            jsonEncode({
              'code': 'Ok',
              'durations': [
                [0, 120]
              ],
            }),
            200,
          ),
        );
        expect(await service.roadDistancesKm(_plaza, [driverA]), isNull);
      });

      test('when the row length does not match the destinations', () async {
        // A mismatched row would misalign every driver with someone else's
        // distance — the worst possible failure, because it looks like data.
        final service = _serviceReturning(
          (_) => http.Response(tableBody([100]), 200),
        );
        expect(
            await service.roadDistancesKm(_plaza, [driverA, driverB]), isNull);
      });

      test('on a malformed body', () async {
        final service = _serviceReturning((_) => http.Response('<html>', 200));
        expect(await service.roadDistancesKm(_plaza, [driverA]), isNull);
      });

      test('when the network is unreachable', () async {
        final service = RouteService(
          baseUrl: 'https://example.test',
          client: MockClient((_) async => throw const SocketExceptionStub()),
        );
        expect(await service.roadDistancesKm(_plaza, [driverA]), isNull);
      });
    });
  });

  group('straight-line fallback', () {
    test('never under-reads the crow-flies distance', () {
      final fallback = TripRoute.straightLine(_plaza, _palengke);
      final crowFlies = distanceKmBetween(_plaza, _palengke);

      // A road trip cannot be shorter than the straight line between its
      // ends, so a fallback that quoted the raw distance would always be low.
      expect(fallback.distanceKm, greaterThanOrEqualTo(crowFlies));
      expect(fallback.isRouted, isFalse);
    });

    test('produces a non-zero duration for a real separation', () {
      final fallback = TripRoute.straightLine(_plaza, _palengke);
      expect(fallback.duration.inMinutes, greaterThan(0));
    });

    test('identical points cost nothing and take no time', () {
      final fallback = TripRoute.straightLine(_plaza, _plaza);
      expect(fallback.distanceKm, closeTo(0, 1e-9));
      expect(fallback.duration, Duration.zero);
    });
  });
}

/// Stands in for a network failure without importing dart:io, which is
/// unavailable when these tests run on the web platform.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: unreachable';
}
