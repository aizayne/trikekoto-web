import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// A place someone searched for.
class GeocodeResult {
  const GeocodeResult({
    required this.name,
    required this.context,
    required this.point,
  });

  /// The short name — "Palengke", "Barangay Hall".
  final String name;

  /// The rest of the address, for telling two similarly-named places apart.
  final String context;

  final LatLng point;

  /// Nominatim returns one long comma-separated address. The first part is
  /// what someone recognises; the rest only matters for disambiguation, so it
  /// is split rather than shown as one unreadable line.
  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    final display = (json['display_name'] as String? ?? '').trim();
    final parts = display.split(',').map((p) => p.trim()).toList();

    return GeocodeResult(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : (parts.isNotEmpty ? parts.first : display),
      context: parts.length > 1 ? parts.sublist(1).take(3).join(', ') : '',
      point: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
    );
  }
}

/// Place search via Nominatim, OpenStreetMap's geocoder.
///
/// > **Nominatim's usage policy forbids client-side autocomplete** on the
/// > public instance, and caps traffic at one request per second. This class
/// > is therefore built for search-on-submit — it is never wired to a
/// > per-keystroke listener — and enforces the rate limit itself rather than
/// > trusting callers to.
/// >
/// > As with routing, the base URL is configurable so a chapter can point at
/// > a self-hosted instance before any real volume.
class GeocodingService {
  GeocodingService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Required by the policy: a genuine identifying agent, not a browser
  /// string. Requests without one are blocked.
  static const _userAgent = 'ph.trikekoto.trikekoto_app';
  static const _timeout = Duration(seconds: 8);
  static const _minGap = Duration(seconds: 1);

  DateTime? _lastRequest;

  /// Searches for [query], preferring results near [near].
  ///
  /// Returns an empty list on any failure — no network, a rate limit, a
  /// malformed reply. Search is a convenience on top of the map picker, and
  /// the picker still works without it, so a failure must never surface as an
  /// error the commuter has to dismiss.
  Future<List<GeocodeResult>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    await _respectRateLimit();

    // A 0.5-degree box around the map centre, roughly 55 km. Bounded, so a
    // search for "Plaza" returns the one down the road rather than one in
    // another province.
    final params = <String, String>{
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '0',
      'countrycodes': 'ph',
      if (near != null) ...{
        'viewbox': '${near.longitude - 0.5},${near.latitude + 0.5},'
            '${near.longitude + 0.5},${near.latitude - 0.5}',
        'bounded': '1',
      },
    };

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/search').replace(queryParameters: params),
            headers: const {'User-Agent': _userAgent},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Geocoding HTTP ${response.statusCode}');
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) {
            try {
              return GeocodeResult.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<GeocodeResult>()
          .toList();
    } catch (e) {
      debugPrint('Geocoding unavailable: $e');
      return const [];
    }
  }

  /// Turns coordinates into something a driver would recognise.
  ///
  /// Used to label the pickup point derived from GPS. A commuter should not
  /// have to name the place they are already standing in, but the driver has
  /// to be told where to go — so the label has to come from somewhere, and a
  /// bare pair of coordinates is not an address anyone can act on.
  ///
  /// Returns null on any failure. The caller keeps the coordinates and
  /// supplies its own wording: the *point* is what dispatch uses, and losing
  /// a nice label must never cost the fix that was already obtained.
  ///
  /// Zoom 18 is roughly building level. Higher returns house numbers that
  /// are mostly absent in barangay addressing; lower returns the barangay
  /// when the commuter is standing outside a named landmark.
  Future<String?> reverseLabel(LatLng point) async {
    await _respectRateLimit();

    final params = <String, String>{
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
    };

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/reverse').replace(queryParameters: params),
            headers: const {'User-Agent': _userAgent},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Reverse geocoding HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      // Nominatim returns `error` with a 200 for a point in the sea.
      if (decoded['error'] != null) return null;

      final address = decoded['address'];
      if (address is Map<String, dynamic>) {
        // Built from parts rather than using `display_name`, which runs to
        // "…, Zambales, Central Luzon, 2205, Philippines" — accurate, and
        // useless in a one-line field on a driver's phone.
        final near = _firstOf(address, const [
          'amenity', 'shop', 'building', 'road', 'hamlet',
        ]);
        final area = _firstOf(address, const [
          'village', 'suburb', 'neighbourhood', 'town', 'city_district',
          'municipality', 'city',
        ]);

        final parts = [near, area].whereType<String>().toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }

      final display = decoded['display_name'];
      if (display is String && display.trim().isNotEmpty) {
        // Last resort: the first two components, which are the specific end.
        return display.split(',').take(2).map((s) => s.trim()).join(', ');
      }
      return null;
    } catch (e) {
      debugPrint('Reverse geocoding unavailable: $e');
      return null;
    }
  }

  static String? _firstOf(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// Holds each request at least a second apart, per the usage policy.
  Future<void> _respectRateLimit() async {
    final last = _lastRequest;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _minGap) await Future<void>.delayed(_minGap - elapsed);
    }
    _lastRequest = DateTime.now();
  }
}

/// Where place search is fetched from.
///
/// Defaults to the public Nominatim instance, which is rate-limited and
/// intended for light use. Point `geocodingBaseUrl` in `config/app` at a
/// self-hosted instance before a real pilot.
const kDefaultGeocodingBaseUrl = 'https://nominatim.openstreetmap.org';

final geocodingBaseUrlProvider = Provider<String>((ref) {
  final raw = ref.watch(appConfigProvider).value?['geocodingBaseUrl'];
  final url = raw is String ? raw.trim() : '';
  return url.startsWith('https://') ? url : kDefaultGeocodingBaseUrl;
});

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(baseUrl: ref.watch(geocodingBaseUrlProvider));
});
