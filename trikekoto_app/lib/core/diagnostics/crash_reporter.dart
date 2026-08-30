import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crash and error reporting.
///
/// The app is distributed as an APK passed around over Wi-Fi, to drivers on
/// handsets nobody on the project owns. When something breaks in the field
/// there is no other way to find out what — a driver reports "the app closed"
/// and that is the whole bug report.
///
/// Runs on the free Spark plan, unlike the Cloud Functions.
///
/// **Not available on web.** `firebase_crashlytics` ships no web
/// implementation, so every call below reaches a method channel nothing is
/// listening on and throws. Because [install] runs before `runApp`, that threw
/// during startup and the web build rendered a blank page — it compiled and
/// deployed perfectly while being completely broken. Each entry point is
/// guarded rather than the call site, so adding a new report cannot
/// reintroduce it.
class CrashReporter {
  const CrashReporter._();

  /// Crash reporting exists on Android only. Web falls back to the console.
  static bool get _off => kIsWeb || kDebugMode;

  /// Installs the global handlers. Call after `Firebase.initializeApp`.
  ///
  /// Collection is **off in debug**: a developer's own hot-reload exceptions
  /// would otherwise drown the real reports from real devices, and the
  /// console has no way to tell them apart.
  static Future<void> install() async {
    // The handlers below are still worth installing on web — they route
    // errors to the browser console instead of vanishing — but nothing
    // Crashlytics-shaped may be touched there.
    if (!kIsWeb) {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    }

    // Framework errors — a widget that threw during build or layout.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (!_off) FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Errors escaping the Dart isolate: a Future nobody awaited, a stream
    // with no error handler. These are the ones that would otherwise vanish
    // silently, which is why they matter more than the framework ones.
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_off) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('Uncaught: $error\n$stack');
      }
      return true;
    };
  }

  /// Records something that went wrong without ending the session.
  ///
  /// [context] should say what the user was attempting — "accepting ride" is
  /// actionable, a bare `permission-denied` is not.
  static Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    required String context,
  }) async {
    if (_off) {
      debugPrint('[$context] $error');
      return;
    }
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: context,
      fatal: false,
    );
  }

  /// Leaves a breadcrumb in the log that accompanies the next crash.
  ///
  /// The value of these is the sequence: "went online → offered ride →
  /// accepted → crash" tells you far more than the stack trace alone.
  static void log(String message) {
    if (_off) return;
    FirebaseCrashlytics.instance.log(message);
  }

  /// Associates reports with a role and, for staff, an identifier.
  ///
  /// Commuters are anonymous by design, so only their role is set — no
  /// identifier is attached to someone who never chose to have one.
  static Future<void> setRole(String role, {String? email}) async {
    if (_off) return;
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCustomKey('role', role);
    if (email != null && email.isNotEmpty) {
      await crashlytics.setUserIdentifier(email);
    }
  }
}

/// Riverpod observer that reports provider failures.
///
/// Most of this app's work happens in providers — a Firestore listener that
/// throws surfaces as an `AsyncError` the UI renders as a message, and would
/// otherwise never be reported at all.
final class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    CrashReporter.recordNonFatal(
      error,
      stackTrace,
      context: 'provider ${context.provider.name ?? context.provider.runtimeType}',
    );
  }
}
