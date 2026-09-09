import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/map/osm_map.dart';
import '../../../core/ui/app_theme.dart';
import '../../rides/data/ride.dart';
import '../../../core/ui/locale_controller.dart';

/// Where the driver is headed right now, and how to get there.
///
/// Until this existed a driver accepted a ride and received a text label —
/// "Plaza" — with no way to see where that was. Fine in a barangay you have
/// driven for years; useless the first week, and useless for any pickup whose
/// name is ambiguous.
///
/// The destination follows the ride state: the pickup while heading out, the
/// drop-off once the passenger is aboard.
class DriverRideMap extends StatelessWidget {
  const DriverRideMap({super.key, required this.ride});

  final Ride ride;

  bool get _headingToPickup => ride.status == RideStatus.accepted;

  GeoPoint? get _destination => _headingToPickup
      ? ride.pickup.geopoint
      : (ride.dropoff.geopoint ?? ride.pickup.geopoint);

  String get _destinationLabel =>
      _headingToPickup ? ride.pickup.label : ride.dropoff.label;

  @override
  Widget build(BuildContext context) {
    final destination = _destination;

    // Rides written by the previous web build carry no coordinates. The rest
    // of the card still works, so this section simply steps aside.
    if (destination == null) return const SizedBox.shrink();

    final driverAt = ride.driverLocation;
    final away = driverAt == null
        ? null
        : distanceKmBetween(driverAt, destination);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _headingToPickup ? Icons.my_location : Icons.place,
              size: AppSpacing.iconSm,
              color: _headingToPickup
                  ? context.semantic.success
                  : context.scheme.error,
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: Text(
                _headingToPickup
                    ? context.l.mapPickUpAt(_destinationLabel)
                    : context.l.mapDropOffAt(_destinationLabel),
                style: context.text.titleSmall,
              ),
            ),
            if (away != null)
              Text(context.l.mapKm(away.toStringAsFixed(1)),
                  style: context.text.bodySmall),
          ],
        ),
        const Gap(AppSpacing.md),

        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 160,
            child: OsmMap(
              center: destination.latLng,
              zoom: 15,
              // Not interactive: this sits inside a scrolling list, and a
              // pannable map there swallows the scroll gesture.
              interactive: false,
              markers: [
                if (ride.pickup.geopoint != null)
                  MapMarkers.pickup(context, ride.pickup.geopoint!.latLng),
                if (ride.dropoff.geopoint != null)
                  MapMarkers.dropoff(context, ride.dropoff.geopoint!.latLng),
                if (driverAt != null)
                  MapMarkers.driver(context, driverAt.latLng),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.md),

        // Hands off to whatever navigation app the driver already uses and
        // trusts. Building turn-by-turn here would be worse than Google Maps
        // or Waze at their own job, and would burn battery doing it.
        OutlinedButton.icon(
          onPressed: () => _navigate(context, destination),
          icon: const Icon(Icons.navigation_outlined),
          label: Text(context.l.mapOpenInMaps),
        ),
      ],
    );
  }

  Future<void> _navigate(BuildContext context, GeoPoint point) async {
    final lat = point.latitude;
    final lng = point.longitude;

    // Tried in order: turn-by-turn navigation, then the generic Android geo:
    // handler, then the Google Maps web URL as a last resort. A driver with
    // no maps app installed still gets something.
    final candidates = <Uri>[
      Uri.parse('google.navigation:q=$lat,$lng&mode=d'),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(_destinationLabel)})'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    ];

    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Try the next one.
      }
    }

    if (context.mounted) {
      showSnack(
        context,
        context.l.mapNoMapsApp(
            lat.toStringAsFixed(5), lng.toStringAsFixed(5)),
        error: true,
      );
    }
  }
}
