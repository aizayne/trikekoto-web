import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/crash_reporter.dart';
import '../../features/commuter/application/profile_photo_service.dart';
import '../../features/commuter/data/rider.dart';
import '../firestore/collection_paths.dart';
import '../providers.dart';

enum AppRole { none, commuter, driver, admin }

class SessionState {
  const SessionState({
    required this.user,
    required this.role,
    required this.loading,
    this.driverStatus,
    this.emailVerified = false,
    this.needsRiderOnboarding = false,
    this.isAnonymous = false,
  });

  const SessionState.loading()
      : user = null,
        role = AppRole.none,
        loading = true,
        driverStatus = null,
        emailVerified = false,
        needsRiderOnboarding = false,
        isAnonymous = false;

  final User? user;
  final AppRole role;
  final bool loading;

  /// Stored rather than read back off [user], so the session can be built in a
  /// test without conjuring a Firebase `User`.
  final bool emailVerified;

  /// Signed in without an account at all.
  ///
  /// Stored rather than read off [user] for the same reason as
  /// [emailVerified]: a widget test can build a session without conjuring a
  /// Firebase `User`.
  final bool isAnonymous;

  /// A phone-verified commuter with no `riders/{uid}` document yet.
  ///
  /// They are already signed in — the OTP succeeded — but have not chosen a
  /// name. The router sends them to onboarding rather than the booking screen,
  /// which is the one place that write is allowed.
  final bool needsRiderOnboarding;

  /// Only meaningful when [role] is [AppRole.driver] — drives the "pending
  /// verification" and "suspended" banners on the dashboard.
  final String? driverStatus;

  bool get isSignedIn => user != null;
  bool get isApprovedDriver =>
      role == AppRole.driver && driverStatus == DriverStatus.approved;

  /// An admin whose address is unconfirmed.
  ///
  /// Only admins are gated on this — `isAdmin()` in the rules requires
  /// `email_verified`, because email/password signup does not prove you own
  /// the address you typed. Drivers are identified by `isSelf()`, which does
  /// not, so a driver never sees the verification screen. The router still sends them to
  /// the panel — the client role check only looks for the `admins` document —
  /// so without this the panel loads and then every read fails with a
  /// permission error that explains nothing.
  bool get isUnverifiedAdmin => role == AppRole.admin && !emailVerified;
}

/// Resolves *who is signed in and what they may do*, which is what the router
/// redirects on.
///
/// Role is derived from Firestore rather than stored on the client: a commuter
/// is anyone with a phone number, an admin is anyone with an `admins/{email}`
/// document, and everyone else with an email is a driver. That mirrors exactly
/// what the security rules check, so the UI can never believe it has a power
/// the server will refuse.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final auth = ref.watch(firebaseAuthProvider);
    final sub = auth.authStateChanges().listen(_resolve);
    ref.onDispose(sub.cancel);
    return const SessionState.loading();
  }

  Future<void> _resolve(User? user) async {
    if (user == null) {
      state = const SessionState(user: null, role: AppRole.none, loading: false);
      return;
    }

    // Anonymous sessions predate the account requirement. They are still
    // resolved rather than signed out, so the router can send them to sign in
    // — dropping them silently would look like the app logging itself out.
    //
    // Their past rides carry this uid, so linking a phone credential to it
    // keeps that history. See [_applyPhoneCredential].
    if (user.isAnonymous) {
      state = SessionState(
        user: user,
        role: AppRole.commuter,
        loading: false,
        isAnonymous: true,
      );
      await CrashReporter.setRole('commuter');
      return;
    }

    // A phone number means a rider account, or someone part-way through
    // creating one. Checked before the email branches because a phone user
    // has no email at all, and the driver fallback below assumes one.
    if ((user.phoneNumber ?? '').isNotEmpty) {
      var hasProfile = false;
      try {
        hasProfile =
            (await ref.read(refsProvider).rider(user.uid).get()).exists;
      } catch (_) {
        // Denied or offline. Treating it as "no profile yet" sends them to
        // onboarding, where the write either succeeds or reports why —
        // better than a commuter screen whose every query then fails.
      }
      state = SessionState(
        user: user,
        role: AppRole.commuter,
        loading: false,
        needsRiderOnboarding: !hasProfile,
      );
      // Role only, as above. A rider chose to identify themselves to the
      // service; that is not a reason to attach their number to crash reports.
      await CrashReporter.setRole('commuter');
      return;
    }

    final email = normalizeEmail(user.email);
    final refs = ref.read(refsProvider);

    // Admin first: an address can only be one or the other, and the admin
    // document is the cheaper lookup.
    try {
      final adminSnap = await refs.adminDoc(email).get();
      if (adminSnap.exists) {
        state = SessionState(
          user: user,
          role: AppRole.admin,
          loading: false,
          emailVerified: user.emailVerified,
        );
        await CrashReporter.setRole('admin', email: email);
        return;
      }
    } catch (_) {
      // Denied simply means "not an admin" — fall through to driver.
    }

    try {
      final driverSnap = await refs.driver(email).get();
      state = SessionState(
        user: user,
        role: AppRole.driver,
        loading: false,
        driverStatus: driverSnap.data()?.status ?? DriverStatus.pending,
        emailVerified: user.emailVerified,
      );
      await CrashReporter.setRole('driver', email: email);
    } catch (_) {
      state = SessionState(
        user: user,
        role: AppRole.driver,
        loading: false,
        emailVerified: user.emailVerified,
      );
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser?.isAnonymous ?? false) {
      await auth.signOut();
    }
    await auth.signInWithEmailAndPassword(
      email: normalizeEmail(email),
      password: password,
    );
  }

  Future<UserCredential> registerDriverAccount(
      String email, String password) async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser?.isAnonymous ?? false) {
      await auth.signOut();
    }
    return auth.createUserWithEmailAndPassword(
      email: normalizeEmail(email),
      password: password,
    );
  }

  // ── Rider accounts (phone + OTP) ─────────────────────────

  /// Starts phone verification. [codeSent] receives the verification id to
  /// pass back to [confirmSmsCode].
  ///
  /// On Android with Play Integrity configured, Firebase may verify the device
  /// silently and never send an SMS at all — [autoVerified] fires instead, and
  /// the caller should not sit on a code-entry screen waiting for a message
  /// that will not arrive.
  /// Held between sending the code and confirming it, on web only.
  ///
  /// The web SDK returns an opaque handle rather than a verification id — the
  /// reCAPTCHA challenge is bound to it — so the code has to be confirmed
  /// through the same object that sent it.
  ConfirmationResult? _webConfirmation;

  Future<void> startPhoneSignIn({
    required String phoneE164,
    required void Function(String verificationId) codeSent,
    required void Function(FirebaseAuthException e) failed,
    void Function()? autoVerified,
  }) async {
    final auth = ref.read(firebaseAuthProvider);

    // Web takes a different path entirely. `verifyPhoneNumber` is not
    // implemented there — the browser SDK requires a reCAPTCHA challenge
    // before it will send an SMS, and exposes that as
    // `signInWithPhoneNumber`. Calling the mobile API on web fails in a way
    // that reads like the number was rejected.
    //
    // The verifier is created for us: invisible, using Firebase's own key,
    // so there is no site key to configure. What it does need is the domain
    // listed under Authentication → Settings → Authorized domains, which
    // `<project>.web.app` is by default.
    if (kIsWeb) {
      // Not caught here. The screen distinguishes a typed auth error from
      // anything else — a blocked reCAPTCHA never becomes a
      // FirebaseAuthException, and swallowing it into `failed` would report
      // it as though Firebase had rejected the number.
      _webConfirmation = await auth.signInWithPhoneNumber(phoneE164);
      // No auto-retrieval in a browser: the code always arrives by SMS and
      // is always typed, so the caller moves straight to the code pane.
      codeSent(_webConfirmation!.verificationId);
      return;
    }

    await auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (credential) async {
        await _applyPhoneCredential(credential);
        autoVerified?.call();
      },
      verificationFailed: failed,
      codeSent: (verificationId, _) => codeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Completes verification with the six digits the rider typed.
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    // On web the code goes back through the handle that sent it, because the
    // reCAPTCHA challenge is tied to that object. This signs in rather than
    // linking, so a web visitor who was anonymous does not carry that uid
    // forward — acceptable now that anonymous booking is retired, and the
    // reason the anonymous-linking path below is mobile-only.
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) {
        throw StateError('no verification in progress');
      }
      await confirmation.confirm(smsCode);
      _webConfirmation = null;
      await _resolve(ref.read(firebaseAuthProvider).currentUser);
      return;
    }

    await _applyPhoneCredential(PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    ));
  }

  /// Attaches the verified number to the session.
  ///
  /// **Links rather than replaces** when the commuter is already anonymous.
  /// That keeps their uid, and `rides.commuterUid` is that uid — so every ride
  /// they booked before signing up stays theirs. Signing in fresh would mint a
  /// new uid and orphan the lot.
  ///
  /// If the number already belongs to another account, linking fails with
  /// `credential-already-in-use`. That is the returning rider on a new device,
  /// so fall back to a plain sign-in: their history lives under the older uid,
  /// which is the one they want back.
  Future<void> _applyPhoneCredential(PhoneAuthCredential credential) async {
    final auth = ref.read(firebaseAuthProvider);
    final current = auth.currentUser;

    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(credential);
        await _resolve(auth.currentUser);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'provider-already-linked') {
          rethrow;
        }
        // Fall through: sign in as the account that already holds the number.
      }
    }

    await auth.signInWithCredential(credential);
    await _resolve(auth.currentUser);
  }

  /// Writes `riders/{uid}` and completes onboarding.
  ///
  /// The phone comes from the token, never from a form — the rules require the
  /// two to match, so a rider cannot claim a number they did not prove.
  Future<void> completeRiderOnboarding({
    required String name,
    Uint8List? photoBytes,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) throw StateError('not signed in');
    final refs = ref.read(refsProvider);

    // Document first, photo second. The Storage rules admit
    // `riders/{uid}/profile` for its owner regardless, but writing the
    // profile first means a failed upload leaves an account that works
    // without a picture — rather than a photo in the bucket belonging to
    // an account that was never created and that nobody will clean up.
    await refs.rider(user.uid).set(RiderWrites.create(
          name: name,
          phone: user.phoneNumber ?? '',
        ));

    if (photoBytes != null) {
      try {
        final url = await ref
            .read(profilePhotoServiceProvider)
            .upload(uid: user.uid, bytes: photoBytes);
        await refs.rider(user.uid).update(
              RiderWrites.setPhoto(url),
            );
      } catch (e, stack) {
        // Never blocks sign-up. A rider who cannot upload on a weak signal
        // still gets an account, and can add the photo later.
        await CrashReporter.recordNonFatal(e, stack,
            context: 'rider profile photo upload');
      }
    }

    await _resolve(user);
  }

  /// Replaces or removes the photo on an existing profile.
  Future<void> setRiderPhoto(Uint8List? bytes) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) throw StateError('not signed in');
    final photos = ref.read(profilePhotoServiceProvider);

    if (bytes == null) {
      await photos.remove(user.uid);
      await ref.read(refsProvider).rider(user.uid).update(
            RiderWrites.setPhoto(null),
          );
      return;
    }

    final url = await photos.upload(uid: user.uid, bytes: bytes);
    await ref.read(refsProvider).rider(user.uid).update(
          RiderWrites.setPhoto(url),
        );
  }

  /// Renames the rider, leaving the photo alone.
  ///
  /// The name is what a driver looks for at the kerb, so this is the one
  /// profile field worth being able to correct after sign-up — a typo made in
  /// the thirty seconds after an OTP would otherwise follow someone forever.
  Future<void> updateRiderName(String name) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) throw StateError('not signed in');
    await ref.read(refsProvider).rider(user.uid).update(
          RiderWrites.updateName(name),
        );
  }

  Future<void> signOut() => ref.read(firebaseAuthProvider).signOut();

  /// Sends the confirmation email to the signed-in address.
  ///
  /// Firebase rate-limits these, so the caller is responsible for not offering
  /// the button again immediately.
  Future<void> sendVerificationEmail() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Re-checks verification after the user has followed the emailed link.
  ///
  /// `reload()` alone is not enough. The security rules read
  /// `request.auth.token.email_verified`, which comes from the **ID token** —
  /// and that token keeps saying `false` until it is refreshed, even once the
  /// local [User] object knows better. Forcing a refresh here is what actually
  /// unlocks the panel; without it the screen would say "verified" while every
  /// read still failed.
  Future<bool> refreshVerification() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshed = ref.read(firebaseAuthProvider).currentUser;
    if (refreshed == null) return false;

    await refreshed.getIdToken(true);
    await _resolve(refreshed);
    return refreshed.emailVerified;
  }

  /// Re-reads the driver's approval state — used after an admin approves, so
  /// the driver does not have to sign out and back in.
  Future<void> refresh() =>
      _resolve(ref.read(firebaseAuthProvider).currentUser);
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
