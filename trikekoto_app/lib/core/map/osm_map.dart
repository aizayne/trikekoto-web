import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_core/http_cache_core.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../ui/app_theme.dart';

/// OpenStreetMap tile layer, configured once.
///
/// OSM's tile usage policy requires a genuine, identifying User-Agent and
/// forbids bulk downloading. Both are honoured here: the package name
/// identifies the app to the tile servers, and tiles are only fetched for
/// what is on screen. Attribution is mandatory and is rendered by
/// [OsmMap] rather than left to each caller to remember.
///
/// Using OSM rather than Google Maps is a cost decision from the original
/// specification — there is no per-load billing here.
class OsmTiles extends StatelessWidget {
  const OsmTiles({super.key});

  static const _urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'ph.trikekoto.trikekoto_app';

  /// On-disk tile cache.
  ///
  /// Two reasons, both from the operating context rather than performance
  /// vanity: drivers work where signal drops out, and a map that goes blank
  /// mid-trip is worse than no map; and OSM's tile policy asks clients not to
  /// re-request tiles they already hold. Kept in the OS cache directory so
  /// Android can evict it under storage pressure without breaking the app.
  static CacheStore? _store;

  static Future<void> initCache() async {
    if (_store != null) return;
    final dir = await getTemporaryDirectory();
    _store = FileCacheStore('${dir.path}/osm_tiles');
  }

  /// Clears cached tiles. Exposed for a future "free up space" control —
  /// the store is in the OS cache directory, so Android may also evict it
  /// on its own.
  static Future<void> clearCache() => _store?.clean() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: _urlTemplate,
      userAgentPackageName: _userAgent,
      maxNativeZoom: 19,
      // Falls back to the plain network provider when the cache has not
      // initialised — a map that draws uncached beats a map that throws.
      tileProvider: _store == null
          ? NetworkTileProvider()
          : CachedTileProvider(
              store: _store!,
              maxStale: const Duration(days: 30),
            ),
      // OSM tiles are drawn for light backgrounds. Rather than ship a second
      // tile source, dark mode dims and inverts them slightly so the map does
      // not glare at a driver working a night shift.
      tileBuilder: Theme.of(context).brightness == Brightness.dark
          ? _darkenTiles
          : null,
    );
  }

  static Widget _darkenTiles(BuildContext context, Widget tile, TileImage _) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.6, -0.2, -0.1, 0, 255, //
        -0.2, -0.6, -0.1, 0, 255, //
        -0.1, -0.2, -0.6, 0, 255, //
        0, 0, 0, 1, 0, //
      ]),
      child: tile,
    );
  }
}

/// A map with tiles, attribution, and optional markers.
///
/// [interactive] is false for the small tracking map embedded in a scrolling
/// card: a pannable map inside a scroll view steals the drag gesture, which
/// the skill's gesture-conflict rule warns against.
class OsmMap extends StatelessWidget {
  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 16,
    this.markers = const [],
    this.route = const [],
    this.controller,
    this.interactive = true,
    this.onPositionChanged,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;

  /// Road path to draw beneath the markers. Empty when no route is known.
  final List<LatLng> route;

  final MapController? controller;
  final bool interactive;
  final void Function(MapCamera camera)? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom
              : InteractiveFlag.none,
        ),
        onPositionChanged: (camera, _) => onPositionChanged?.call(camera),
      ),
      children: [
        const OsmTiles(),
        // Drawn under the markers so a pin is never hidden by the line.
        if (route.length > 1)
          PolylineLayer(
            polylines: [
              // A casing stroke beneath keeps the route legible over both
              // pale streets and dark parkland.
              Polyline(
                points: route,
                strokeWidth: 7,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              Polyline(
                points: route,
                strokeWidth: 4,
                color: AppColors.accent,
              ),
            ],
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        // Required by the OSM tile usage policy.
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

/// Map pins. Built from theme tokens so they read in both themes.
class MapMarkers {
  const MapMarkers._();

  static Marker pickup(BuildContext context, LatLng point) => _pin(
        point: point,
        color: context.semantic.success,
        icon: Icons.my_location,
      );

  static Marker dropoff(BuildContext context, LatLng point) => _pin(
        point: point,
        color: context.scheme.error,
        icon: Icons.place,
      );

  static Marker driver(BuildContext context, LatLng point) => _pin(
        point: point,
        color: AppColors.accent,
        icon: Icons.electric_rickshaw,
      );

  static Marker _pin({
    required LatLng point,
    required Color color,
    required IconData icon,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: AppSpacing.iconSm),
      ),
    );
  }
}

/// Bridges Firestore's [GeoPoint] and flutter_map's [LatLng] so neither type
/// leaks into the other layer.
extension GeoPointToLatLng on GeoPoint {
  LatLng get latLng => LatLng(latitude, longitude);
}

extension LatLngToGeoPoint on LatLng {
  GeoPoint get geoPoint => GeoPoint(latitude, longitude);
}
