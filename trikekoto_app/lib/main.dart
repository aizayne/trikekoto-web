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
import 'core/ui/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'core/ui/theme_controller.dart';
import 'firebase_options.dart';

/// reCAPTCHA **Enterprise** site key, for App Check on the web build.
///
/// **Public by design.** It ships in the page and identifies the site; it
/// authorises nothing, and the secret half never leaves Google. Committing it
/// is correct — the same reasoning that puts the Firebase API keys in
/// `firebase_options.dart`.
///
/// Empty means *no web attestation*: `activate()` is called without a web
/// provider, exactly as before this existed. That fallback has to keep
/// working, because enforcement is a console switch — turning it on against a
/// build with no key locks the web app out of its own backend, and the symptom
/// is every Firestore read failing at once with nothing on screen to explain
/// it.
///
/// Note that Enterprise and the deprecated classic reCAPTCHA hand Firebase
/// different halves: classic wants the **secret** key in the console, while
/// Enterprise wants the **site** key in both the console and here. Pasting a
/// classic secret into an Enterprise field fails in a way the console does not
/// explain.
///
/// Overridable per build for a second project or a staging site:
///
///     flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=6Lxxxx
const _recaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '6LdegbItAAAAAO4d1IMzgHpV-pephdYMk2jpmJIT',
);

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
      // Enterprise rather than the classic v3 provider: Firebase deprecated
      // plain reCAPTCHA for App Check, and the console now refuses to
      // recommend it. Enterprise's free tier is 10,000 assessments a month,
      // which a single TODA chapter will not approach.
      //
      // See [_recaptchaSiteKey] for why an empty key must stay valid.
      providerWeb: _recaptchaSiteKey.isEmpty
          ? null
          : ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
    );
  } catch (e, stack) {
    debugPrint('App Check unavailable: $e');
    await CrashReporter.recordNonFatal(e, stack, context: 'app check init');
  }

  // Says, in the one place someone would look, whether this build attests
  // itself on web. An unattested web build is not broken — it is unprotected,
  // and that difference is invisible until a bill arrives.
  if (kIsWeb && _recaptchaSiteKey.isEmpty) {
    debugPrint(
      'App Check: no web site key compiled in — this build is UNATTESTED on '
      'web. Do not enable App Check enforcement until one is set.',
    );
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
      // Filipino unless the person chose otherwise. Not the device locale:
      // a cheap Android handset ships set to English and most owners never
      // change it, so following the device would hand English to exactly the
      // drivers this was built for. See LocaleController.
      locale: ref.watch(localeProvider).locale,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
