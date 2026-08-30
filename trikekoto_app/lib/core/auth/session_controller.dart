import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/crash_reporter.dart';
import '../firestore/collection_paths.dart';
import '../providers.dart';

enum AppRole { none, commuter, driver, admin }

class SessionState {
  const SessionState({
    required this.user,
    required this.role,
    required this.loading,
    this.driverStatus,
  });

  const SessionState.loading()
      : user = null,
        role = AppRole.none,
        loading = true,
        driverStatus = null;

  final User? user;
  final AppRole role;
  final bool loading;

  /// Only meaningful when [role] is [AppRole.driver] — drives the "pending
  /// verification" and "suspended" banners on the dashboard.
  final String? driverStatus;

  bool get isSignedIn => user != null;
  bool get isApprovedDriver =>
      role == AppRole.driver && driverStatus == DriverStatus.approved;
}

/// Resolves *who is signed in and what they may do*, which is what the router
/// redirects on.
///
/// Role is derived from Firestore rather than stored on the client: a commuter
/// is anyone anonymous, an admin is anyone with an `admins/{email}` document,
/// and everyone else with an email is a driver. That mirrors exactly what the
/// security rules check, so the UI can never believe it has a power the server
/// will refuse.
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

    if (user.isAnonymous) {
      state =
          SessionState(user: user, role: AppRole.commuter, loading: false);
      // Role only — a commuter is anonymous by design, and attaching an
      // identifier to someone who never chose one would undo that.
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
        state = SessionState(user: user, role: AppRole.admin, loading: false);
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
      );
      await CrashReporter.setRole('driver', email: email);
    } catch (_) {
      state = SessionState(user: user, role: AppRole.driver, loading: false);
    }
  }

  /// Commuters never see a sign-in form — an anonymous account is created on
  /// demand purely so their ride document has an owner.
  Future<void> continueAsCommuter() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser != null && !auth.currentUser!.isAnonymous) {
      await auth.signOut();
    }
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    } else {
      await _resolve(auth.currentUser);
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

  Future<void> signOut() => ref.read(firebaseAuthProvider).signOut();

  /// Re-reads the driver's approval state — used after an admin approves, so
  /// the driver does not have to sign out and back in.
  Future<void> refresh() =>
      _resolve(ref.read(firebaseAuthProvider).currentUser);
}

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
