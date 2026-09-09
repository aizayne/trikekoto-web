import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../routing/geocoding_service.dart';
import '../ui/app_theme.dart';
import 'osm_map.dart';

/// What the picker returns: a point plus the label the commuter typed for it.
class PickedLocation {
  const PickedLocation({required this.point, required this.label});

  final LatLng point;
  final String label;
}

/// Full-screen map for choosing a pickup or drop-off point.
///
/// Uses a fixed centre crosshair rather than a draggable pin: the map moves
/// under a stationary marker. Dragging a pin means the user's thumb covers
/// the exact spot they are aiming at, and it is close to impossible
/// one-handed — which is how someone flagging a trike is actually holding
/// their phone.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.title,
    required this.initialCenter,
    this.initialLabel = '',
  });

  final String title;
  final LatLng initialCenter;
  final String initialLabel;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _controller = MapController();
  late final TextEditingController _label =
      TextEditingController(text: widget.initialLabel);

  final _search = TextEditingController();

  late LatLng _center = widget.initialCenter;
  bool _locating = false;
  bool _searching = false;
  List<GeocodeResult> _results = const [];

  @override
  void dispose() {
    _label.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Runs only when the commuter submits — never per keystroke.
  ///
  /// Nominatim's usage policy forbids client-side autocomplete on the public
  /// instance, so wiring this to an onChanged listener would be a breach as
  /// well as a way to get the app's traffic blocked.
  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.length < 3) return;

    setState(() {
      _searching = true;
      _results = const [];
    });

    final results = await ref
        .read(geocodingServiceProvider)
        .search(query, near: _center);

    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
    });

    if (results.isEmpty) {
      // Not "no such place" — the search is deliberately bounded to about
      // 55 km around the map centre, so a real place further out comes back
      // empty. Saying it was not found would be a lie the commuter cannot
      // check, and would read as the app not knowing their own province.
      showSnack(context,
          'Walang nakitang "$query" malapit dito. Kung malayo ito, i-drag '
          'muna ang mapa papunta roon — o ilagay ang pin nang manu-mano.');
    }
  }

  /// Moves the map to a result and pre-fills the label with its name, which
  /// is usually what the commuter would have typed anyway.
  void _useResult(GeocodeResult result) {
    _controller.move(result.point, 17);
    setState(() {
      _center = result.point;
      _results = const [];
      if (_label.text.trim().isEmpty) _label.text = result.name;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showSnack(context, 'Location permission is off. Enable it in '
              'Settings to centre the map on you.', error: true);
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final point = LatLng(pos.latitude, pos.longitude);
      _controller.move(point, 17);
      setState(() => _center = point);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      showSnack(context, 'Give this place a name so your driver recognises it.',
          error: true);
      return;
    }
    Navigator.of(context)
        .pop(PickedLocation(point: _center, label: label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          OsmMap(
            controller: _controller,
            center: widget.initialCenter,
            zoom: 17,
            onPositionChanged: (camera) => _center = camera.center,
            // Tap to place the pin. The crosshair stays the mechanism — the
            // map animates so the tapped point lands under it — because a pin
            // that jumps out from under the crosshair would leave two things
            // on screen claiming to be the chosen spot.
            onTap: (point) {
              _controller.move(point, _controller.camera.zoom);
              setState(() => _center = point);
            },
          ),

          // The crosshair sits dead centre and does not move. Offset upward
          // by half its height so the pin's point, not its middle, marks the
          // spot.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: context.scheme.error,
                  shadows: const [
                    Shadow(color: Colors.black38, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),

          // Search sits at the top, over the map, where a phone user's eye
          // goes first.
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    color: context.scheme.surface,
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: 'Search a place',
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: AppSpacing.iconSm,
                                  height: AppSpacing.iconSm,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Search',
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _runSearch,
                              ),
                      ),
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.sm),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: context.scheme.surface,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border:
                            Border.all(color: context.scheme.outlineVariant),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: r.context.isEmpty
                                ? null
                                : Text(r.context,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            onTap: () => _useResult(r),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Labelled, not an icon.
          //
          // This was a small unlabelled FAB, and "centre the map on me" is the
          // most likely thing a commuter setting a pickup wants — they are
          // usually standing at it. A crosshair glyph does not say that to
          // someone who has not used a maps app, and the people this is for
          // include drivers and passengers who have not. Words cost one line
          // of layout and remove the guess.
          Positioned(
            right: AppSpacing.lg,
            bottom: 210,
            child: FloatingActionButton.extended(
              heroTag: 'my-location',
              onPressed: _locating ? null : _goToMyLocation,
              backgroundColor: context.scheme.surface,
              foregroundColor: context.scheme.secondary,
              icon: _locating
                  ? const SizedBox(
                      width: AppSpacing.iconSm,
                      height: AppSpacing.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_locating ? 'Hinahanap…' : 'Nasa akin ngayon'),
            ),
          ),

          // The confirm sheet is anchored to the bottom, inside the safe
          // area, so the primary action stays reachable with one thumb.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.scheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: context.scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'I-drag ang mapa para ilagay ang pin — o hanapin sa '
                      'itaas, o gamitin ang lokasyon mo.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                    const Gap(AppSpacing.md),
                    TextField(
                      controller: _label,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name this place',
                        hintText: 'e.g. Plaza, Palengke, Barangay Hall',
                      ),
                      onSubmitted: (_) => _confirm(),
                    ),
                    const Gap(AppSpacing.lg),
                    FilledButton(
                      onPressed: _confirm,
                      child: const Text('Confirm location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
