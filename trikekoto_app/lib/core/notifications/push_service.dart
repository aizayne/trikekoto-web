import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles a message that arrives while the app is terminated or backgrounded.
///
/// Must be a top-level function: Android spins up a separate isolate for it,
/// so it cannot close over anything from the running app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Deliberately empty. The notification payload is displayed by the system
  // without our involvement, and doing Firestore work in this isolate would
  // mean a second Firebase initialisation for no benefit — the driver taps
  // through to a live app that reads the ride anyway.
  debugPrint('Background push: ${message.messageId}');
}

/// Registration and delivery of push notifications.
///
/// Only the *receiving* half lives in the app. Sending requires a server
/// credential, and embedding one in an APK handed around by QR code would let
/// anyone push to any driver — so the send side is a Cloud Function.
class PushService {
  PushService(this._messaging);

  final FirebaseMessaging _messaging;

  /// Asks for notification permission and returns the device token.
  ///
  /// Android 13+ requires a runtime grant for POST_NOTIFICATIONS; before that
  /// it is implicit. Returns null when the user declines — a driver who says
  /// no still gets in-app offers while the screen is open, so this must not
  /// be treated as a failure.
  Future<String?> registerForOffers() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  /// Fires when the token rotates — Android reissues them on reinstall, cache
  /// clears, and restores. A stale token means a driver silently stops
  /// receiving offers, which is indistinguishable from having no work.
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  /// Messages arriving while the app is open and in front. The system does
  /// not draw a notification for these, so the UI has to react itself.
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  /// The user tapping a notification that opened or resumed the app.
  Stream<RemoteMessage> get openedFromNotification =>
      FirebaseMessaging.onMessageOpenedApp;

  /// The notification that launched a terminated app, if any.
  Future<RemoteMessage?> get initialMessage => _messaging.getInitialMessage();
}

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref.watch(firebaseMessagingProvider)));

/// The current device token, or null when permission was declined.
///
/// Kept as a provider so both the driver presence writer and the commuter's
/// ride creation can attach it without each managing its own registration.
final fcmTokenProvider = StreamProvider<String?>((ref) async* {
  final service = ref.watch(pushServiceProvider);

  yield await service.registerForOffers();

  // A rotated token supersedes the first, so the next presence write or ride
  // creation carries the current value. A stale token is indistinguishable
  // from having no work, so this is not cosmetic.
  yield* service.tokenRefreshes;
});

/// Payload keys the Cloud Functions send. Shared here so the two sides cannot
/// drift apart silently.
class PushData {
  const PushData._();

  static const type = 'type';
  static const rideId = 'rideId';

  static const typeRideOffer = 'ride_offer';
  static const typeRideAccepted = 'ride_accepted';
  static const typeRideArrived = 'ride_arrived';
  static const typeRideCompleted = 'ride_completed';
}
