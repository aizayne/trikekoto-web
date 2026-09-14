import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/map/osm_map.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/routing/geocoding_service.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/build_stamp.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/admin/data/ride_analytics.dart';
import 'package:trikekoto_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:trikekoto_app/features/admin/presentation/ride_analytics_panel.dart';
import 'package:trikekoto_app/features/commuter/application/commuter_location.dart';
import 'package:trikekoto_app/features/commuter/application/dispatch_controller.dart'
    as commuter;
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/features/commuter/presentation/rider_sign_in_screen.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/drivers/presentation/driver_dashboard_screen.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/identity/data/id_submission.dart';
import 'package:trikekoto_app/features/identity/presentation/id_review_screen.dart';
import 'package:trikekoto_app/features/identity/presentation/id_verification_screen.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// Screenshots for the end-user manual (docs/manual/*.png).
///
/// Not a test of behaviour, and skipped in ordinary runs. The manual needs
/// pictures of real screens, and signing a phone into live accounts to take
/// them would put real names, numbers and IDs into a thesis appendix. These
/// render the shipped widgets over made-up data instead, so the pictures are
/// reproducible and can be regenerated whenever a screen changes:
///
///   flutter test test/manual/manual_screenshots_test.dart \
///     --dart-define=MANUAL_SCREENSHOTS=true \
///     --dart-define=FLUTTER_ROOT=C:/path/to/flutter
///
/// Then rebuild the manual with scripts/build_user_manual.cjs.
///
/// Fifteen map tiles for the tracking screen are fetched from OpenStreetMap
/// once per run, well within its tile usage policy.

const _enabled = bool.fromEnvironment('MANUAL_SCREENSHOTS');
const _flutterRoot = String.fromEnvironment('FLUTTER_ROOT');
const _version = '1.0.5 (6)';
const _outDir = 'docs/manual';
const _phone = Size(390, 844);

// San Marcelino, Zambales — the chapter this is built for.
const _plaza = GeoPoint(14.97470, 120.15770);
const _market = GeoPoint(14.97930, 120.16350);
const _trike = GeoPoint(14.97690, 120.16010);

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  final material = '$_flutterRoot/bin/cache/artifacts/material_fonts';
  await family('Roboto', [
    for (final w in ['regular', 'medium', 'bold', 'italic', 'light'])
      '$material/roboto-$w.ttf',
  ]);
  await family('MaterialIcons', ['$material/materialicons-regular.otf']);
  // Roboto has no ★. A phone falls back to a system symbol face; here the
  // fallback has to be named.
  const symbols = 'C:/Windows/Fonts/seguisym.ttf';
  if (File(symbols).existsSync()) await family('Symbols', [symbols]);
  await family('Poppins', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Poppins-$w.ttf',
  ]);
}

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

class _FixedSession extends SessionController {
  _FixedSession(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _OnlinePresence extends PresenceController {
  @override
  bool build() => true;
}

class _FakeIdService implements IdVerificationService {
  _FakeIdService(this.card);
  final Uint8List card;

  @override
  Future<Uint8List?> reviewerImage(String uid) async => card;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGeocoding extends GeocodingService {
  _FakeGeocoding() : super(baseUrl: 'http://localhost');

  @override
  Future<String?> reverseLabel(LatLng point) async => 'Plaza, San Marcelino';
}

/// Stands where the commuter is, so the pickup fills itself in as it does on
/// a phone.
class _FakeLocation extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      Position(
        latitude: _plaza.latitude,
        longitude: _plaza.longitude,
        timestamp: DateTime(2026, 9, 14, 8),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

/// Tiles around the trike at the tracking map's zoom, fetched before any
/// widget test starts. A widget test runs on a fake clock that network and
/// file IO never complete on, so the map is fed from memory instead.
final _tiles = <String, Uint8List>{};
const _tileZoom = 15;

Future<void> _fetchTiles() async {
  final n = 1 << _tileZoom;
  final x = ((_trike.longitude + 180) / 360 * n).floor();
  final lat = _trike.latitude * math.pi / 180;
  final y = ((1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * n)
      .floor();

  final saved = HttpOverrides.current;
  HttpOverrides.global = null; // the test binding refuses all requests
  final client = HttpClient()..userAgent = 'ph.trikekoto.trikekoto_app';
  try {
    for (var dx = -2; dx <= 2; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final key = '$_tileZoom/${x + dx}/${y + dy}';
        final req = await client
            .getUrl(Uri.parse('https://tile.openstreetmap.org/$key.png'));
        final res = await req.close();
        final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
        if (res.statusCode == 200) _tiles[key] = Uint8List.fromList(bytes);
      }
    }
  } finally {
    client.close();
    HttpOverrides.global = saved;
  }
}

class _MemoryTiles extends TileProvider {
  /// A transparent pixel for anything outside the fetched block.
  static final _blank = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) =>
      MemoryImage(_tiles['${c.z}/${c.x}/${c.y}'] ?? _blank);
}

final _captureKey = GlobalKey();

Widget _app(Widget home, List overrides) => ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(_FixedTheme.new),
        appVersionProvider.overrideWith((ref) async => _version),
        ...overrides.cast(),
      ],
      child: RepaintBoundary(
        key: _captureKey,
        // A router, because some screens ask GoRouter whether they can pop.
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          // The app opens in Filipino, and the manual quotes Filipino labels
          // first, so the pictures are in Filipino too.
          locale: const Locale('fil'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: _withRoboto(AppTheme.light),
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => home),
          ]),
        ),
      ),
    );

/// Body text in the app names no family and gets the platform face (Roboto
/// on Android). In a test the platform face is a box font, so name it.
ThemeData _withRoboto(ThemeData t) {
  TextStyle? r(TextStyle? s) => s?.copyWith(
        fontFamily: s.fontFamily ?? 'Roboto',
        fontFamilyFallback: const ['Symbols'],
      );
  TextTheme all(TextTheme x) => x.copyWith(
        displayLarge: r(x.displayLarge),
        displayMedium: r(x.displayMedium),
        displaySmall: r(x.displaySmall),
        headlineLarge: r(x.headlineLarge),
        headlineMedium: r(x.headlineMedium),
        headlineSmall: r(x.headlineSmall),
        titleLarge: r(x.titleLarge),
        titleMedium: r(x.titleMedium),
        titleSmall: r(x.titleSmall),
        bodyLarge: r(x.bodyLarge),
        bodyMedium: r(x.bodyMedium),
        bodySmall: r(x.bodySmall),
        labelLarge: r(x.labelLarge),
        labelMedium: r(x.labelMedium),
        labelSmall: r(x.labelSmall),
      );
  return t.copyWith(
    textTheme: all(t.textTheme),
    primaryTextTheme: all(t.primaryTextTheme),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Lets real image work (tile downloads, PNG decoding) finish, then settles.
Future<void> _settleImages(WidgetTester tester, {int seconds = 1}) async {
  // Downloads finish in real time but only reach the screen on a frame, so
  // alternate the two rather than waiting once.
  for (var i = 0; i < seconds * 4; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (final e in find.byType(Image).evaluate()) {
    final image = (e.widget as Image).image;
    await tester.runAsync(() => precacheImage(image, e));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Uint8List> _capture(WidgetTester tester, {Finder? of}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      of ?? find.byKey(_captureKey));
  late Uint8List png;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    png = data!.buffer.asUint8List();
  });
  return png;
}

Future<void> _save(WidgetTester tester, String name) async {
  // Tests draw without shadows, and check the flag is back before a test
  // ends. The manual should show the app as it looks, so shadows go on for
  // the one frame that is captured.
  debugDisableShadows = false;
  for (final r in tester.allRenderObjects) {
    r.markNeedsPaint();
  }
  await tester.pump();
  final png = await _capture(tester);
  debugDisableShadows = true;
  await tester.pump();
  Directory(_outDir).createSync(recursive: true);
  File('$_outDir/$name.png').writeAsBytesSync(png);
}

Ride _acceptedRide() => Ride.fromMap(const {
      'commuterUid': 'rider-uid',
      'commuterName': 'Maria',
      'commuterPhone': '09181234567',
      'status': 'accepted',
      'assignedDriver': 'juan@toda.ph',
      'pickup': {'label': 'Plaza, San Marcelino', 'geopoint': _plaza},
      'dropoff': {'label': 'Palengke', 'geopoint': _market},
      'driverSnapshot': {
        'email': 'juan@toda.ph',
        'firstName': 'Juan',
        'phone': '09171234567',
        'plateNumber': 'ABC 1234',
      },
      'driverLocation': _trike,
    }, 'ride-1');

Driver _driver(String email, String first, String last, String status) =>
    Driver.fromMap({
      'email': email,
      'uid': 'uid-$first',
      'firstName': first,
      'lastName': last,
      'phone': '09171234567',
      'plateNumber': 'ABC 1234',
      'todaChapter': 'San Marcelino TODA',
      'status': status,
      'ratingSum': 23,
      'ratingCount': 5,
    }, email);

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
    await _fetchTiles();
  });


  testWidgets('1 · ID verification', skip: !_enabled, (tester) async {
    await _size(tester, const Size(390, 1140));
    await tester.pumpWidget(_app(
      const IdVerificationScreen(role: IdRole.rider),
      [
        myIdSubmissionProvider.overrideWith((ref) => Stream.value(null)),
        myIdVerifiedProvider.overrideWith((ref) => Stream.value(false)),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1234-5678-9012-3456');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _save(tester, 'fig-1-id-verification');
  });

  testWidgets('2 · sign in with a number', skip: !_enabled, (tester) async {
    await _size(tester, _phone);
    await tester.pumpWidget(_app(const RiderSignInScreen(), const []));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0917 123 4567');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _save(tester, 'fig-2-sign-in');
  });

  testWidgets('3 · booking', skip: !_enabled, (tester) async {
    GeolocatorPlatform.instance = _FakeLocation();
    await _size(tester, _phone);
    await tester.pumpWidget(_app(const CommuterBookingScreen(), [
      commuter.myActiveRideProvider.overrideWith((ref) => Stream.value(null)),
      myRiderProfileProvider.overrideWith((ref) => Stream.value(null)),
      geocodingServiceProvider.overrideWithValue(_FakeGeocoding()),
    ]));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Maria');
    await tester.enterText(fields.at(1), '0918 123 4567');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _save(tester, 'fig-3-booking');
  });

  testWidgets('4 · tracking an accepted ride', skip: !_enabled,
      (tester) async {
    // Real tiles, so the map in the picture is a map.
    OsmTiles.debugTileProvider = _MemoryTiles();
    addTearDown(() => OsmTiles.debugTileProvider = null);
    await _size(tester, _phone);
    await tester.pumpWidget(_app(const CommuterBookingScreen(), [
      commuter.myActiveRideProvider
          .overrideWith((ref) => Stream.value(_acceptedRide())),
      myRiderProfileProvider.overrideWith((ref) => Stream.value(null)),
      commuterPositionProvider.overrideWith(
          (ref) => Stream.value(LatLng(_plaza.latitude, _plaza.longitude))),
      geocodingServiceProvider.overrideWithValue(_FakeGeocoding()),
    ]));
    await tester.pump();
    await _settleImages(tester, seconds: 6);
    await _save(tester, 'fig-4-tracking');
  });

  testWidgets('5 · driver online', skip: !_enabled, (tester) async {
    await _size(tester, _phone);
    await tester.pumpWidget(_app(const DriverDashboardScreen(), [
      myDriverProfileProvider.overrideWith((ref) => Stream.value(
          _driver('juan@toda.ph', 'Juan', 'Dela Cruz', DriverStatus.approved))),
      myIdVerifiedProvider.overrideWith((ref) => Stream.value(true)),
      myOffersProvider.overrideWith((ref) => Stream.value(const <Ride>[])),
      myActiveRideProvider.overrideWith((ref) => Stream.value(null)),
      presenceProvider.overrideWith(_OnlinePresence.new),
    ]));
    await tester.pumpAndSettle();
    await _save(tester, 'fig-5-driver-online');
  });

  testWidgets('6 · admin dashboard', skip: !_enabled, (tester) async {
    final now = DateTime(2026, 9, 14, 16);
    Ride ride(RideStatus s, {int? rating, String? driver, int hoursAgo = 1}) =>
        Ride(
          id: 'r-${s.wire}-$rating-$driver-$hoursAgo',
          commuterUid: 'uid',
          commuterName: 'Commuter',
          commuterPhone: '09171234567',
          pickup: const RidePlace(label: 'Plaza'),
          dropoff: const RidePlace(label: 'Palengke'),
          dispatch: const RideDispatch(),
          status: s,
          assignedDriver: driver,
          rating: rating,
          createdAt:
              Timestamp.fromDate(now.subtract(Duration(hours: hoursAgo))),
        );
    final rides = [
      for (var i = 0; i < 9; i++)
        ride(RideStatus.completed,
            rating: i.isEven ? 5 : 4,
            driver: i < 5 ? 'juan@toda.ph' : 'pedro@toda.ph',
            hoursAgo: i + 1),
      ride(RideStatus.cancelled, hoursAgo: 3),
      ride(RideStatus.expired, hoursAgo: 5),
    ];
    final pendingId = IdSubmission.fromMap(const {
      'subjectUid': 'rider-uid-1',
      'role': 'rider',
      'idType': 'national_id',
      'idNumber': '1234-5678-9012-3456',
      'status': 'pending',
    }, 'rider-uid-1');

    await _size(tester, const Size(390, 1560));
    await tester.pumpWidget(_app(const AdminDashboardScreen(), [
      sessionProvider.overrideWith(() => _FixedSession(const SessionState(
            user: null,
            role: AppRole.admin,
            loading: false,
            emailVerified: true,
          ))),
      allDriversProvider.overrideWith((ref) => Stream.value([
            _driver('ana@toda.ph', 'Ana', 'Santos', DriverStatus.pending),
            _driver('juan@toda.ph', 'Juan', 'Dela Cruz', DriverStatus.approved),
            _driver('pedro@toda.ph', 'Pedro', 'Reyes', DriverStatus.approved),
          ])),
      rideAnalyticsProvider.overrideWith((ref) async => RideAnalytics.from(
            rides,
            window: AnalyticsWindow.today,
            now: now,
          )),
      openFeedbackCountProvider.overrideWith((ref) => Stream.value(1)),
      pendingIdSubmissionsProvider
          .overrideWith((ref) => Stream.value([pendingId])),
    ]));
    await tester.pumpAndSettle();
    await _save(tester, 'fig-6-admin-dashboard');
  });

  testWidgets('7 · reviewing an ID', skip: !_enabled, (tester) async {
    // A sample card, drawn here, so no real identity document is ever near
    // the manual.
    await _size(tester, const Size(340, 214));
    final cardKey = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: cardKey, child: const _SampleCard()),
    ));
    await tester.pumpAndSettle();
    final card = await _capture(tester, of: find.byKey(cardKey));

    await _size(tester, const Size(390, 480));
    await tester.pumpWidget(_app(const IdReviewScreen(), [
      pendingIdSubmissionsProvider.overrideWith((ref) => Stream.value([
            IdSubmission.fromMap(const {
              'subjectUid': 'rider-uid-1',
              'role': 'rider',
              'idType': 'national_id',
              'idNumber': '1234-5678-9012-3456',
              'status': 'pending',
            }, 'rider-uid-1'),
          ])),
      idVerificationServiceProvider.overrideWithValue(_FakeIdService(card)),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.image_outlined));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await _settleImages(tester);
    await _save(tester, 'fig-7-id-review');
  });
}

class _SampleCard extends StatelessWidget {
  const _SampleCard();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F3864);
    TextStyle t(double size, [FontWeight w = FontWeight.w400]) => TextStyle(
        fontFamily: 'Roboto', fontSize: size, fontWeight: w, color: ink);
    return Container(
      width: 340,
      height: 214,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3ECF7), Color(0xFFF7F3E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HALIMBAWA · SAMPLE ONLY', style: t(10, FontWeight.w700)),
          Text('Not a real identity document', style: t(9)),
          const SizedBox(height: 18),
          Row(children: [
            Container(
              width: 70,
              height: 86,
              color: const Color(0xFFB8C7DB),
              child: const Icon(Icons.person, size: 56, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DELA CRUZ', style: t(15, FontWeight.w700)),
              Text('MARIA', style: t(13, FontWeight.w500)),
              const SizedBox(height: 10),
              Text('1234-5678-9012-3456', style: t(12, FontWeight.w500)),
            ]),
          ]),
        ]),
      ]),
    );
  }
}
