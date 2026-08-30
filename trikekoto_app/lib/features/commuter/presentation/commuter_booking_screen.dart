import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/fare/fare_calculator.dart';
import '../../../core/config/app_config.dart';
import '../../../core/diagnostics/crash_reporter.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/map/location_picker_screen.dart';
import '../../../core/map/osm_map.dart';
import '../../../core/providers.dart';
import '../../../core/routing/route_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../rides/data/ride.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../application/dispatch_controller.dart';

class CommuterBookingScreen extends ConsumerStatefulWidget {
  const CommuterBookingScreen({super.key});

  @override
  ConsumerState<CommuterBookingScreen> createState() =>
      _CommuterBookingScreenState();
}

class _CommuterBookingScreenState extends ConsumerState<CommuterBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  /// Chosen on the map rather than typed. Coordinates are what dispatch and
  /// the fare need; a free-text label alone gave neither.
  PickedLocation? _pickup;
  PickedLocation? _dropoff;

  /// Manila as a last resort, only until the first GPS fix lands.
  static const _fallbackCenter = LatLng(14.5995, 120.9842);

  @override
  void dispose() {
    for (final c in [_name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The road route between the two chosen points, once both exist.
  ///
  /// Fetched rather than computed: a straight line under-reads against the
  /// road a trike actually travels, and a fare quoted low becomes an argument
  /// at the drop-off.
  TripRoute? _route;
  bool _routing = false;

  double? get _distanceKm => _route?.distanceKm;

  /// Re-routes whenever both endpoints are known. Failure is silent by
  /// design — [RouteService] degrades to a straight-line estimate and flags
  /// it, so booking is never blocked by a routing outage.
  Future<void> _refreshRoute() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _routing = true);
    try {
      final route = await ref.read(routeServiceProvider).between(
            _pickup!.point.geoPoint,
            _dropoff!.point.geoPoint,
          );
      if (mounted) setState(() => _route = route);
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _pick({required bool isPickup}) async {
    final existing = isPickup ? _pickup : _dropoff;
    final center = existing?.point ??
        _pickup?.point ??
        (await _currentPoint())?.latLng ??
        _fallbackCenter;

    if (!mounted) return;
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Set pickup' : 'Set drop-off',
          initialCenter: center,
          initialLabel: existing?.label ?? '',
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      if (isPickup) {
        _pickup = result;
      } else {
        _dropoff = result;
      }
      // The previous route is stale the moment either end moves.
      _route = null;
    });
    await _refreshRoute();
  }

  Future<GeoPoint?> _currentPoint() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _book() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickup == null || _dropoff == null) {
      showSnack(context, 'Set both your pickup and drop-off on the map.',
          error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final km = _distanceKm;
      final quote = km == null
          ? null
          : estimateFare(distanceKm: km, config: ref.read(fareConfigProvider));

      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      final doc = await ref
          .read(firestoreProvider)
          .collection(FsCollections.rides)
          .add(RideWrites.create(
            commuterUid: uid,
            commuterName: _name.text,
            commuterPhone: _phone.text,
            pickup: RidePlace(
              label: _pickup!.label,
              geopoint: _pickup!.point.geoPoint,
            ),
            dropoff: RidePlace(
              label: _dropoff!.label,
              geopoint: _dropoff!.point.geoPoint,
            ),
            distanceKm: km,
            // Quoted before booking now that both endpoints are known. The
            // driver still records the actual distance on completion.
            fareEstimate: quote?.total,
            commuterFcmToken: await ref.read(fcmTokenProvider.future)
                .catchError((_) => null),
          ));

      await ref.read(dispatchControllerProvider).start(doc.id);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Ride ride) async {
    try {
      await ref.read(dispatchControllerProvider).stop();
      await ref
          .read(refsProvider)
          .ride(ride.id)
          .update(RideWrites.cancelByCommuter());
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _rate(Ride ride, int stars) async {
    try {
      final refs = ref.read(refsProvider);
      await refs.ride(ride.id).update(RideWrites.rate(stars: stars));
      if (mounted) showSnack(context, 'Salamat sa rating!');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
      return;
    }

    // Second half of the rating: the driver's aggregate.
    //
    // Deliberately best-effort and outside the block above. Once the
    // `onRideRated` Cloud Function is deployed and the rules lock these
    // fields to `if false`, this write starts being refused — and it must
    // fail quietly, because by then the function has already counted the
    // rating and the commuter's part is done. Surfacing an error here would
    // tell them their rating failed when it did not.
    //
    // The function is idempotent, so during the migration window an older
    // APK still attempting this cannot double-count.
    final driverEmail = ride.assignedDriver;
    if (driverEmail == null) return;
    try {
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.drivers)
          .doc(driverEmail)
          .update(RideWrites.ratingIncrement(stars));
    } catch (e, stack) {
      await CrashReporter.recordNonFatal(e, stack,
          context: 'client rating aggregate (expected after step 68)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(myActiveRideProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a ride'),
        actions: [
          IconButton(
            tooltip: 'Report a problem',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () =>
                showFeedbackSheet(context, role: FeedbackRole.commuter),
          ),
          IconButton(
            tooltip: 'Exit',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: rideAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            message: describeError(e),
            onRetry: () => ref.invalidate(myActiveRideProvider),
          ),
          data: (ride) {
            final active = ride != null && !ride.status.isTerminal;
            final rateable = ride != null && ride.isRateable;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: active
                      ? _ActiveRideCard(
                          ride: ride, onCancel: () => _cancel(ride))
                      : rateable
                          ? _RateCard(
                              ride: ride,
                              onRate: (stars) => _rate(ride, stars),
                            )
                          : _bookingForm(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bookingForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Saan tayo?', style: context.text.headlineSmall),
          const Gap(AppSpacing.xs),
          Text(
            'We offer your ride to the nearest available driver first.',
            style: context.text.bodySmall,
          ),
          const Gap(AppSpacing.xxl),

          // The journey reads as one connected route: two stops joined by a
          // rail, each opening the map.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                children: [
                  _RouteRow(
                    icon: Icons.my_location,
                    color: context.semantic.success,
                    label: 'Pickup',
                    value: _pickup?.label,
                    placeholder: 'Set on map',
                    onTap: () => _pick(isPickup: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 18,
                          child: VerticalDivider(
                            width: 1,
                            color: context.scheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RouteRow(
                    icon: Icons.place,
                    color: context.scheme.error,
                    label: 'Drop-off',
                    value: _dropoff?.label,
                    placeholder: 'Set on map',
                    onTap: () => _pick(isPickup: false),
                  ),
                ],
              ),
            ),
          ),

          // The fare appears as soon as both ends are known, so nobody is
          // asked to commit to a trip without knowing the price.
          if (_routing) ...[
            const Gap(AppSpacing.md),
            const _RoutingPlaceholder(),
          ] else if (_route != null) ...[
            const Gap(AppSpacing.md),
            _FareQuoteRow(
              route: _route!,
              quote: estimateFare(
                distanceKm: _route!.distanceKm,
                config: ref.read(fareConfigProvider),
              ),
            ),
          ],
          const Gap(AppSpacing.lg),

          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const Gap(AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText: 'So your driver can reach you.',
            ),
            validator: (v) => (v == null || v.trim().length < 7)
                ? 'Enter a mobile number the driver can call'
                : null,
          ),
          const Gap(AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _busy ? null : _book,
            icon: _busy
                ? const SizedBox(
                    width: AppSpacing.iconSm,
                    height: AppSpacing.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onAccent,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(_busy ? 'Finding a driver…' : 'Find a driver'),
          ),
        ],
      ),
    );
  }
}

/// Live map of the trike approaching, embedded in the active-ride card.
///
/// Deliberately non-interactive: it sits inside a scrolling column, and a
/// pannable map there would swallow the scroll gesture. Tapping opens a
/// full-screen interactive view instead, which keeps one gesture per region.
class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final driver = ride.driverLocation!.latLng;
    final pickup = ride.pickup.geopoint!.latLng;
    final away = distanceKmBetween(ride.driverLocation!, ride.pickup.geopoint!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                OsmMap(
                  center: driver,
                  zoom: 15,
                  interactive: false,
                  markers: [
                    MapMarkers.pickup(context, pickup),
                    MapMarkers.driver(context, driver),
                    if (ride.dropoff.geopoint != null)
                      MapMarkers.dropoff(context, ride.dropoff.geopoint!.latLng),
                  ],
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _FullScreenTracking(ride: ride),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.sm),
        Text(
          ride.status == RideStatus.inTransit
              ? 'On the way to your drop-off'
              : '${away.toStringAsFixed(1)} km away',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _FullScreenTracking extends StatelessWidget {
  const _FullScreenTracking({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: OsmMap(
        center: ride.driverLocation!.latLng,
        zoom: 16,
        markers: [
          if (ride.pickup.geopoint != null)
            MapMarkers.pickup(context, ride.pickup.geopoint!.latLng),
          MapMarkers.driver(context, ride.driverLocation!.latLng),
          if (ride.dropoff.geopoint != null)
            MapMarkers.dropoff(context, ride.dropoff.geopoint!.latLng),
        ],
      ),
    );
  }
}

/// One stop on the route. A full-width row rather than a text field: it
/// opens the map, and its whole height is the tap target.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: AppSpacing.iconMd),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.bodySmall),
                  Text(
                    chosen ? value! : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: chosen
                          ? context.scheme.onSurface
                          : context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.map_outlined,
                size: AppSpacing.iconSm,
                color: context.scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Placeholder while the route is being fetched.
///
/// Reserves the same height as the quote so the button below it does not jump
/// under the thumb the moment the answer arrives.
class _RoutingPlaceholder extends StatelessWidget {
  const _RoutingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: AppSpacing.iconSm,
            height: AppSpacing.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const Gap(AppSpacing.md),
          Text('Working out the route…', style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// The estimate, shown before booking.
class _FareQuoteRow extends StatelessWidget {
  const _FareQuoteRow({required this.route, required this.quote});

  final TripRoute route;
  final FareQuote quote;

  @override
  Widget build(BuildContext context) {
    final minutes = route.duration.inMinutes;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined,
              size: AppSpacing.iconMd,
              color: context.scheme.onSecondaryContainer),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated fare',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSecondaryContainer),
                ),
                Text(
                  '${route.distanceKm.toStringAsFixed(1)} km'
                  '${minutes > 0 ? ' · about $minutes min' : ''}',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSecondaryContainer),
                ),
                // Says plainly when routing was unavailable, rather than
                // presenting a rough guess with the same confidence as a
                // real road distance.
                if (!route.isRouted)
                  Text(
                    'Approximate — could not reach the route service',
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSecondaryContainer,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            quote.formattedTotal,
            style: context.text.headlineSmall
                ?.copyWith(color: context.scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Errors state what failed and offer a way forward, rather than leaving a
/// dead screen with a code on it.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: AppSpacing.iconLg, color: context.scheme.onSurfaceVariant),
            const Gap(AppSpacing.lg),
            Text(message,
                textAlign: TextAlign.center, style: context.text.bodyMedium),
            const Gap(AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({required this.ride, required this.onCancel});

  final Ride ride;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searching = ride.status == RideStatus.searching;
    final driver = ride.driverSnapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (searching)
                  const SizedBox(
                    width: AppSpacing.iconMd,
                    height: AppSpacing.iconMd,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Icon(Icons.check_circle,
                      color: context.semantic.success,
                      size: AppSpacing.iconMd),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Text(
                    switch (ride.status) {
                      RideStatus.searching => 'Looking for a driver…',
                      RideStatus.accepted => 'Driver is on the way',
                      RideStatus.inTransit => 'On the way to your drop-off',
                      _ => ride.status.wire,
                    },
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (searching) ...[
              const Gap(AppSpacing.md),
              // A determinate bar: the search is finite, so showing how much
              // of it is spent is more honest than an endless spinner.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: LinearProgressIndicator(
                  value: ride.dispatch.depth / DispatchDefaults.maxDriversToTry,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
              ),
              const Gap(AppSpacing.sm),
              Text(
                'Asked ${ride.dispatch.depth} of '
                '${DispatchDefaults.maxDriversToTry} nearby drivers',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (driver != null) ...[
              const Divider(height: AppSpacing.xxxl),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      driver.firstName.isEmpty
                          ? '?'
                          : driver.firstName.characters.first.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.firstName,
                            style: theme.textTheme.titleSmall),
                        Text(driver.plateNumber,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  // Calling the driver is the action a waiting commuter
                  // reaches for, so it gets a real target rather than a line
                  // of text they have to copy.
                  IconButton.filledTonal(
                    tooltip: 'Call ${driver.firstName}',
                    icon: const Icon(Icons.phone),
                    onPressed: () => _dial(context, driver.phone),
                  ),
                ],
              ),
            ],
            const Divider(height: AppSpacing.xxxl),
            _row(context, Icons.my_location, ride.pickup.label),
            const Gap(AppSpacing.sm),
            _row(context, Icons.place_outlined, ride.dropoff.label),
            // Live tracking. The driver mirrors GPS onto this ride document,
            // so the map updates from the same snapshot listener that drives
            // the rest of the card — no extra reads, no access to the driver
            // index.
            if (ride.driverLocation != null && ride.pickup.geopoint != null) ...[
              const Gap(AppSpacing.lg),
              _TrackingMap(ride: ride),
            ],
            if (ride.status != RideStatus.inTransit) ...[
              const Gap(AppSpacing.xl),
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel ride'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _dial(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        showSnack(context, 'Could not open the dialler. Number: $phone',
            error: true);
      }
    }
  }

  Widget _row(BuildContext context, IconData icon, String text) => Row(
        children: [
          Icon(icon,
              size: AppSpacing.iconSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const Gap(AppSpacing.md),
          Expanded(child: Text(text)),
        ],
      );
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.ride, required this.onRate});

  final Ride ride;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How was your ride?',
                style: Theme.of(context).textTheme.titleMedium),
            const Gap(AppSpacing.xs),
            Text(
              ride.driverSnapshot?.firstName ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (ride.fareEstimate != null) ...[
              const Gap(AppSpacing.lg),
              Text(
                '₱${ride.fareEstimate!.toStringAsFixed(0)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                ride.distanceKm == null
                    ? 'Estimated fare'
                    : 'Estimated fare • ${ride.distanceKm!.toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const Gap(AppSpacing.xs / 2),
              Text(
                'Straight-line estimate. Pay the posted TODA fare.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 11,
                    ),
              ),
            ],
            const Gap(AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.star_border),
                    onPressed: () => onRate(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
