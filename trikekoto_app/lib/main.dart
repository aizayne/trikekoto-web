import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/diagnostics/crash_reporter.dart';
import 'core/map/osm_map.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/ui/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Installed first so anything that fails below is itself reported.
  await CrashReporter.install();

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

  runApp(
    const ProviderScope(
      observers: [CrashReportingObserver()],
      child: TrikeKoToApp(),
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
      // Drivers work night shifts; following the system setting means the
      // screen is not a torch at 2am.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
