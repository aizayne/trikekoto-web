import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/diagnostics/crash_reporter.dart';
import 'core/map/osm_map.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/ui/app_theme.dart';
import 'core/ui/theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Installed first so anything that fails below is itself reported.
  await CrashReporter.install();

  // Attests that requests come from a genuine build of this app.
  //
  // Phone sign-in sends real SMS, billed per message. Without App Check a
  // modified client can pump verification requests at someone else's number
  // and at your account — the abuse costs the attacker nothing and you a
  // bill. This is the control that makes an OTP flow safe to expose.
  //
  // Debug builds use the debug provider: it prints a token on first run that
  // must be registered under App Check in the console, or every request from
  // a development device is rejected.
  //
  // Guarded like every other startup call here. App Check failing is a reason
  // to be unattested, not a reason to render a blank page.
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
      // Replace with the site key from Firebase Console → App Check → Web.
      // Left null so an unconfigured project still runs; enforcement is a
      // console setting and turning it on before this is set would lock the
      // web build out of its own backend.
      providerWeb: null,
    );
  } catch (e, stack) {
    debugPrint('App Check unavailable: \$e');
    await CrashReporter.recordNonFatal(e, stack, context: 'app check init');
  }

  // Must be registered before runApp: Android may deliver a message into a
  // fresh isolate before any widget exists. On web the equivalent is a service
  // worker, which this build does not ship — registering here throws.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Map tiles survive signal loss. Failure here is not fatal — the map falls
  // back to fetching every tile — so it must never block startup.
  try {
    await OsmTiles.initCache();
  } catch (e, stack) {
    debugPrint('Tile cache unavailable, falling back to network: $e');
    await CrashReporter.recordNonFatal(e, stack, context: 'tile cache init');
  }

  // Loaded before the first frame so the stored theme applies immediately.
  // Reading it later would paint light first and correct to dark a frame
  // on — a white flash on every cold start for the people who chose dark.
  //
  // Guarded because this throws on platforms with no implementation, and an
  // unguarded failure here happens *before* runApp — which renders a blank
  // page with no clue as to why. The app starts fine without it; the theme
  // simply stops being remembered between launches.
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e, stack) {
    debugPrint('Preferences unavailable, theme will not persist: $e');
    await CrashReporter.recordNonFatal(e, stack, context: 'preferences init');
  }

  runApp(
    ProviderScope(
      observers: const [CrashReportingObserver()],
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TrikeKoToApp(),
    ),
  );
}

class TrikeKoToApp extends ConsumerWidget {
  const TrikeKoToApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TrikeKoTo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Light by default — the white-and-orange scheme is the product's
      // identity, and nobody should have to configure their phone to see it.
      // Drivers on night shifts can switch from the app bar; that choice is
      // theirs to make rather than their handset's.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
