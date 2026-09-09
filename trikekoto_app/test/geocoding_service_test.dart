import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/routing/geocoding_service.dart';

/// Tests for place search.
///
/// Two things matter more than the happy path. Nominatim's usage policy caps
/// traffic at one request per second and blocks clients that ignore it, so
/// the rate limit is a correctness property rather than politeness. And a
/// search failure must stay silent — the map picker works without it, so an
/// outage should never become an error the commuter has to dismiss.

const _manila = LatLng(14.5995, 120.9842);

GeocodingService _serviceReturning(
  http.Response Function(http.Request) handler,
) =>
    GeocodingService(
      baseUrl: 'https://example.test',
      client: MockClient((r) async => handler(r)),
    );

String _body(List<Map<String, dynamic>> places) => jsonEncode(places);

Map<String, dynamic> _place({
  String? name,
  required String display,
  required String lat,
  required String lon,
}) =>
    {
      'name': ?name,
      'display_name': display,
      'lat': lat,
      'lon': lon,
    };

void main() {
  group('parsing', () {
    test('splits the short name from its address context', () async {
      final service = _serviceReturning(
        (_) => http.Response(
          _body([
            _place(
              name: 'Palengke',
              display: 'Palengke, Poblacion, Batangas, Calabarzon, Philippines',
              lat: '14.6010',
              lon: '120.9850',
            ),
          ]),
          200,
        ),
      );

      final results = await service.search('palengke', near: _manila);

      expect(results, hasLength(1));
      expect(results.first.name, 'Palengke');
      // Context is trimmed to a few parts — the full Nominatim string is
      // unreadable on a phone.
      expect(results.first.context, 'Poblacion, Batangas, Calabarzon');
      expect(results.first.point.latitude, closeTo(14.6010, 1e-6));
    });

    test('falls back to the first address part when there is no name',
        () async {
      final service = _serviceReturning(
        (_) => http.Response(
          _body([
            _place(
              display: 'Barangay Hall, Poblacion, Philippines',
              lat: '14.6',
              lon: '121.0',
            ),
          ]),
          200,
        ),
      );

      final results = await service.search('barangay hall');
      expect(results.first.name, 'Barangay Hall');
    });

    test('skips a malformed entry instead of failing the whole search',
        () async {
      final service = _serviceReturning(
        (_) => http.Response(
          jsonEncode([
            {'display_name': 'Broken', 'lat': 'not-a-number', 'lon': '121.0'},
            _place(display: 'Good Place', lat: '14.6', lon: '121.0'),
          ]),
          200,
        ),
      );

      final results = await service.search('anything');
      expect(results, hasLength(1));
      expect(results.first.name, 'Good Place');
    });
  });

  group('request shape', () {
    test('bounds the search near the map and restricts it to the Philippines',
        () async {
      late Uri captured;
      final service = _serviceReturning((request) {
        captured = request.url;
        return http.Response(_body(const []), 200);
      });

      await service.search('plaza', near: _manila);

      final q = captured.queryParameters;
      expect(q['countrycodes'], 'ph');
      expect(q['bounded'], '1');
      expect(q['viewbox'], isNotNull);
      // Without bounding, "Plaza" returns matches from other provinces ahead
      // of the one down the road.
      expect(q['q'], 'plaza');
    });

    test('identifies itself, as the usage policy requires', () async {
      late Map<String, String> headers;
      final service = _serviceReturning((request) {
        headers = request.headers;
        return http.Response(_body(const []), 200);
      });

      await service.search('plaza');
      expect(headers['User-Agent'], contains('trikekoto'));
    });

    test('does not call the network for a query under three characters',
        () async {
      var calls = 0;
      final service = _serviceReturning((_) {
        calls++;
        return http.Response(_body(const []), 200);
      });

      await service.search('pl');
      await service.search('  a  ');
      await service.search('');

      expect(calls, 0);
    });
  });

  group('rate limiting', () {
    test('holds consecutive searches at least a second apart', () async {
      final service = _serviceReturning(
        (_) => http.Response(_body(const []), 200),
      );

      final started = DateTime.now();
      await service.search('one');
      await service.search('two');
      final elapsed = DateTime.now().difference(started);

      // Nominatim blocks clients that exceed one request per second, so this
      // gap is a correctness property, not politeness.
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(950));
    });
  });

  group('failure is silent', () {
    test('an HTTP error yields no results rather than throwing', () async {
      final service =
          _serviceReturning((_) => http.Response('rate limited', 429));
      expect(await service.search('plaza'), isEmpty);
    });

    test('a malformed body yields no results', () async {
      final service = _serviceReturning((_) => http.Response('<html>', 200));
      expect(await service.search('plaza'), isEmpty);
    });

    test('an unreachable network yields no results', () async {
      final service = GeocodingService(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => throw Exception('unreachable')),
      );
      expect(await service.search('plaza'), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Reverse geocoding — labelling the GPS-derived pickup point.
  //
  // The commuter never types this label, so whatever comes back is what the
  // driver is sent to find them by. A wrong-but-plausible label is worse than
  // no label, because nothing downstream can tell the difference.
  // ══════════════════════════════════════════════════════════
  group('reverse geocoding', () {
    String reverseBody(Map<String, dynamic> body) => jsonEncode(body);

    test('names the specific place and the area it is in', () async {
      final service = _serviceReturning(
        (_) => http.Response(
          reverseBody({
            'display_name': 'Sari-sari Store, Purok 3, San Marcelino, '
                'Zambales, Central Luzon, 2207, Philippines',
            'address': {
              'shop': 'Sari-sari Store',
              'village': 'Purok 3',
              'municipality': 'San Marcelino',
              'state': 'Central Luzon',
              'country': 'Philippines',
            },
          }),
          200,
        ),
      );

      // Built from parts, not display_name: the full string trails through
      // province, region, postcode and country, none of which help a driver
      // and all of which crowd out the part that does.
      expect(await service.reverseLabel(_manila), 'Sari-sari Store, Purok 3');
    });

    test('falls back through the address keys when the specific ones are absent',
        () async {
      // Barangay addressing often has no shop or building, only a road.
      final service = _serviceReturning(
        (_) => http.Response(
          reverseBody({
            'address': {
              'road': 'Maharlika Highway',
              'town': 'San Marcelino',
            },
          }),
          200,
        ),
      );

      expect(await service.reverseLabel(_manila),
          'Maharlika Highway, San Marcelino');
    });

    test('returns one part when only one is known', () async {
      final service = _serviceReturning(
        (_) => http.Response(
          reverseBody({
            'address': {'municipality': 'San Marcelino'},
          }),
          200,
        ),
      );
      expect(await service.reverseLabel(_manila), 'San Marcelino');
    });

    test('uses the leading part of display_name when address is unusable',
        () async {
      final service = _serviceReturning(
        (_) => http.Response(
          reverseBody({
            'display_name': 'Plaza, San Marcelino, Zambales, Philippines',
            'address': {'country': 'Philippines'},
          }),
          200,
        ),
      );
      expect(await service.reverseLabel(_manila), 'Plaza, San Marcelino');
    });

    test('sends lat and lon as separate parameters', () async {
      late Uri captured;
      final service = _serviceReturning((request) {
        captured = request.url;
        return http.Response(
          reverseBody({'address': {'road': 'Main'}}),
          200,
        );
      });

      await service.reverseLabel(_manila);

      expect(captured.path, endsWith('/reverse'));
      expect(captured.queryParameters['lat'], '14.5995');
      expect(captured.queryParameters['lon'], '120.9842');
    });

    group('returns null so the caller keeps its own wording', () {
      test('when Nominatim reports an error inside a 200', () async {
        // A point in the sea comes back as HTTP 200 with an error body.
        // Treating that as success would label the pickup "Unable to
        // geocode", which the commuter would then send to a driver.
        final service = _serviceReturning(
          (_) => http.Response(
            reverseBody({'error': 'Unable to geocode'}),
            200,
          ),
        );
        expect(await service.reverseLabel(_manila), isNull);
      });

      test('when nothing usable is in the response', () async {
        final service = _serviceReturning(
          (_) => http.Response(reverseBody({'address': <String, dynamic>{}}), 200),
        );
        expect(await service.reverseLabel(_manila), isNull);
      });

      test('on an HTTP error', () async {
        final service =
            _serviceReturning((_) => http.Response('rate limited', 429));
        expect(await service.reverseLabel(_manila), isNull);
      });

      test('on a malformed body', () async {
        final service = _serviceReturning((_) => http.Response('<html>', 200));
        expect(await service.reverseLabel(_manila), isNull);
      });

      test('on an unreachable network', () async {
        final service = GeocodingService(
          baseUrl: 'https://example.test',
          client: MockClient((_) async => throw Exception('unreachable')),
        );
        expect(await service.reverseLabel(_manila), isNull);
      });
    });

    test('is held to the same one-per-second rate limit as search', () async {
      // The reverse lookup runs on screen load, right when a commuter may
      // also start typing a search. Two requests inside a second is exactly
      // what gets a client blocked by the usage policy.
      final service = _serviceReturning(
        (_) => http.Response(reverseBody({'address': {'road': 'Main'}}), 200),
      );

      final started = DateTime.now();
      await service.reverseLabel(_manila);
      await service.reverseLabel(_manila);

      expect(DateTime.now().difference(started),
          greaterThanOrEqualTo(const Duration(seconds: 1)));
    });
  });
}
