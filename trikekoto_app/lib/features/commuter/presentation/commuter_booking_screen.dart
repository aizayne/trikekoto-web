import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/diagnostics/crash_reporter.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/map/location_picker_screen.dart';
import '../../../core/map/osm_map.dart';
import '../../../core/providers.dart';
import '../../../core/routing/geocoding_service.dart';
import '../../../core/routing/route_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../rides/data/ride.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../application/commuter_location.dart';
import '../application/dispatch_controller.dart';
import '../../../core/ui/locale_controller.dart';

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
  /// dispatch needs; a free-text label alone gave neither.
  PickedLocation? _pickup;
  PickedLocation? _dropoff;

  /// Manila as a last resort, only until the first GPS fix lands.
  static const _fallbackCenter = LatLng(14.5995, 120.9842);

  /// True while the opening GPS fix and its address lookup are in flight, so
  /// the pickup field can say it is working rather than looking empty.
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Fire and forget. Nothing on this screen waits for it — the commuter can
    // set both points by hand while it is still running, and if they do, the
    // result is discarded rather than overwriting them.
    _seedPickupFromGps();
  }

  /// Sets the pickup to wherever the commuter is standing.
  ///
  /// Most trike rides start where the passenger already is, so an empty
  /// pickup field asks them to state something the phone already knows. This
  /// fills it in and lets them change it, rather than making the common case
  /// the manual one.
  ///
  /// Every step is allowed to fail. A denied permission, disabled location
  /// services, or an unreachable Nominatim all leave the screen exactly as it
  /// was before this existed: an empty pickup field the commuter taps to set
  /// on the map. This is a convenience, and a convenience that blocks booking
  /// is a defect.
  Future<void> _seedPickupFromGps() async {
    setState(() => _locating = true);
    try {
      final point = await _currentPoint();
      // Bail out on every await, not just the first. The commuter may have
      // tapped Pickup and chosen a point while the fix was in flight, and
      // overwriting their explicit choice with a guess is the one behaviour
      // this must never have.
      if (!mounted || point == null || _pickup != null) return;

      final latLng = point.latLng;
      setState(() {
        _pickup = PickedLocation(
          point: latLng,
          // Stands in until the address arrives, and stays if it never does.
          // The point is what dispatch uses; the label only has to be
          // something the driver can read, and this is honest about what it
          // is. `_confirm()` in the picker refuses an empty label, so the
          // pickup can never end up nameless.
          label: context.l.bookCurrentLocation,
        );
      });

      final address =
          await ref.read(geocodingServiceProvider).reverseLabel(latLng);
      if (!mounted || address == null) return;
      // Re-check: the commuter may have replaced the pickup during the
      // lookup, in which case this label belongs to a point they discarded.
      if (_pickup?.point != latLng) return;

      setState(() => _pickup = PickedLocation(point: latLng, label: address));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The road route between the two chosen points, once both exist.
  ///
  /// Fetched rather than computed: a straight line under-reads badly against
  /// the road a trike actually travels, so the distance shown would be wrong
  /// in the direction that matters.
  TripRoute? _route;
  bool _routing = false;

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
          title: isPickup ? context.l.bookSetPickup : context.l.bookSetDropoff,
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
      showSnack(context, context.l.bookSetBoth,
          error: true);
      return;
    }

    setState(() => _busy = true);
    try {
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
            // Copied across so the driver can recognise who they are
            // collecting. A driver cannot read `riders/{uid}` — and should
            // not be able to — so this is the only way it reaches them.
            // Null for anonymous commuters, which is most of them.
            commuterPhotoUrl:
                ref.read(myRiderProfileProvider).value?.profilePhotoUrl,
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
      if (mounted) showSnack(context, context.l.rateThanks);
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
        title: Text(context.l.bookTitle),
        actions: [
          const ThemeToggleButton(),
          // Shows the rider's own photo once they have one, so the way to
          // change it is the thing it changes.
          IconButton(
            tooltip: context.l.bookProfile,
            icon: Builder(builder: (context) {
              final url =
                  ref.watch(myRiderProfileProvider).value?.profilePhotoUrl;
              if (url == null) return const Icon(Icons.person_outline);
              return CircleAvatar(
                radius: AppSpacing.iconSm / 2 + 3,
                foregroundImage: NetworkImage(url),
                backgroundColor: context.scheme.secondaryContainer,
                child: Icon(Icons.person_outline,
                    size: AppSpacing.iconSm,
                    color: context.scheme.onSecondaryContainer),
              );
            }),
            onPressed: () => context.push('/commuter/profile'),
          ),
          IconButton(
            tooltip: context.l.bookReportProblem,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () =>
                showFeedbackSheet(context, role: FeedbackRole.commuter),
          ),
          IconButton(
            tooltip: context.l.bookExit,
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
          Text(context.l.bookWhereTo, style: context.text.headlineSmall),
          const Gap(AppSpacing.xs),
          Text(
            context.l.bookNearestFirst,
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
                    label: context.l.bookPickup,
                    value: _pickup?.label,
                    // Says what is happening while the opening fix runs.
                    // "Set on map" during those seconds reads as though
                    // nothing is coming, and the commuter taps away from a
                    // field that was about to fill itself in.
                    placeholder: _locating && _pickup == null
                        ? context.l.bookLocating
                        : context.l.bookSetOnMap,
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
                    label: context.l.bookDropoff,
                    value: _dropoff?.label,
                    placeholder: context.l.bookSetOnMap,
                    onTap: () => _pick(isPickup: false),
                  ),
                ],
              ),
            ),
          ),

          // Distance and time appear as soon as both ends are known, so
          // nobody commits to a trip without knowing how far it is.
          if (_routing) ...[
            const Gap(AppSpacing.md),
            const _RoutingPlaceholder(),
          ] else if (_route != null) ...[
            const Gap(AppSpacing.md),
            _TripSummaryRow(route: _route!),
          ],
          const Gap(AppSpacing.lg),

          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l.bookYourName,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? context.l.bookEnterName : null,
          ),
          const Gap(AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.l.signInNumberLabel,
              prefixIcon: const Icon(Icons.phone_outlined),
              helperText: context.l.bookNumberHelper,
            ),
            validator: (v) => (v == null || v.trim().length < 7)
                ? context.l.bookNumberInvalid
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
            label: Text(
                _busy ? context.l.bookFinding : context.l.bookFindDriver),
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
class _TrackingMap extends ConsumerWidget {
  const _TrackingMap({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(commuterPositionProvider).value;
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
                    // Last, so the dot sits above the pins rather than
                    // disappearing under one when the trike arrives.
                    if (me != null) MapMarkers.you(context, me),
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
              ? context.l.trackOnTheWay
              : context.l.trackKmAway(away.toStringAsFixed(1)),
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _FullScreenTracking extends ConsumerWidget {
  const _FullScreenTracking({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(commuterPositionProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l.trackTitle)),
      body: OsmMap(
        center: ride.driverLocation!.latLng,
        zoom: 16,
        markers: [
          if (ride.pickup.geopoint != null)
            MapMarkers.pickup(context, ride.pickup.geopoint!.latLng),
          MapMarkers.driver(context, ride.driverLocation!.latLng),
          if (ride.dropoff.geopoint != null)
            MapMarkers.dropoff(context, ride.dropoff.geopoint!.latLng),
          if (me != null) MapMarkers.you(context, me),
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
/// Reserves the same height as the summary so the button below does not jump
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
          Text(context.l.trackWorkingRoute, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// How far and how long, shown before booking.
///
/// Deliberately carries no price. TODA tariffs are set by ordinance and
/// posted at the terminal; a second figure on a phone could only ever
/// disagree with the official one, and the disagreement would surface at the
/// drop-off with the driver, not with us.
class _TripSummaryRow extends StatelessWidget {
  const _TripSummaryRow({required this.route});

  final TripRoute route;

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
          Icon(Icons.route_outlined,
              size: AppSpacing.iconMd,
              color: context.scheme.onSecondaryContainer),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l.trackTrip,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSecondaryContainer),
                ),
                Text(
                  context.l.trackTripSummary(
                    route.distanceKm.toStringAsFixed(1),
                    minutes > 0 ? context.l.trackAboutMinutes('$minutes') : '',
                  ),
                  style: context.text.titleMedium
                      ?.copyWith(color: context.scheme.onSecondaryContainer),
                ),
                // Says plainly when routing was unavailable, rather than
                // presenting a rough guess with the same confidence as a
                // real road distance.
                if (!route.isRouted)
                  Text(
                    context.l.trackApproximate,
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSecondaryContainer,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
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
              label: Text(context.l.trackTryAgain),
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
                      RideStatus.searching => context.l.statusSearching,
                      RideStatus.accepted => context.l.statusAccepted,
                      RideStatus.inTransit => context.l.statusInTransit,
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
                context.l.statusAsked('${ride.dispatch.depth}',
                    '${DispatchDefaults.maxDriversToTry}'),
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
                    tooltip: context.l.callDriver(driver.firstName),
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
                child: Text(context.l.cancelRide),
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
        showSnack(context, context.l.dialerFailed(phone),
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
            Text(context.l.rateTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const Gap(AppSpacing.xs),
            Text(
              ride.driverSnapshot?.firstName ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Gap(AppSpacing.md),
            Text(
              context.l.ratePayCash,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
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
