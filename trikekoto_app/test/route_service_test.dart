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
