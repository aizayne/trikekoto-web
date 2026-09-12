import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/config_editor_screen.dart';
import '../../features/admin/presentation/feedback_inbox_screen.dart';
import '../../features/commuter/presentation/commuter_booking_screen.dart';
import '../../features/commuter/presentation/rider_onboarding_screen.dart';
import '../../features/commuter/presentation/rider_profile_screen.dart';
import '../../features/commuter/presentation/rider_sign_in_screen.dart';
import '../../features/drivers/presentation/driver_dashboard_screen.dart';
import '../../features/identity/data/id_submission.dart';
import '../../features/identity/presentation/id_review_screen.dart';
import '../../features/identity/presentation/id_verification_screen.dart';
import '../../features/drivers/presentation/driver_register_screen.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/landing/presentation/staff_login_screen.dart';
import '../auth/session_controller.dart';
import '../../features/identity/application/id_verification_service.dart';

/// Role-based routing.
///
/// The redirect is the only place that decides which shell a user lands in, so
/// there is no way to reach the admin panel by deep link without the role to
/// back it up — and even if there were, the rules would refuse the reads.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  // Approval arrives while the person waits on the ID screen, so the
  // router has to hear about it without a sign-in event to prompt it.
  ref.listen(myIdVerifiedProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.loading) return null;

      // Read once, used by both roles that the ID gate covers. Until the
      // first answer arrives, stay put — the same way a loading session
      // does — rather than flash a screen the person may not be allowed.
      final idCheck = ref.read(myIdVerifiedProvider);
      final idPending = !idCheck.hasValue && !idCheck.hasError;
      // An error reads as unverified. Showing the ID screen by mistake is
      // recoverable; the rules would refuse the booking regardless.
      final idVerified = idCheck.value == true;

      final signedIn = session.isSignedIn;
      // `/rider-signin` is public: a commuter reaches it before they have an
      // account, and often before they are signed in at all.
      final onPublic = loc == '/' ||
          loc == '/login' ||
          loc == '/register' ||
          loc == '/rider-signin';

      if (!signedIn) return onPublic ? null : '/';

      switch (session.role) {
        case AppRole.commuter:
          // Every commuter has an account. A session left over from before
          // that change is anonymous and has no phone number, so it is sent
          // to sign in rather than allowed to keep booking.
          if (session.isAnonymous) {
            return loc == '/rider-signin' ? null : '/rider-signin';
          }
          // A phone-verified commuter with no profile yet is signed in but
          // cannot do anything useful: the booking screen would work, but
          // they have no name for a driver to look for. Onboarding is the
          // only write the rules allow them at this point.
          if (session.needsRiderOnboarding) {
            return loc == '/rider-onboarding' ? null : '/rider-onboarding';
          }
          // The ID gate, after onboarding so there is a name on the account.
          // An unverified commuter can reach exactly two screens: the one that
          // submits an ID, and their profile — so an account can always be
          // deleted, including one that was never verified.
          //
          // This is the honest-client half of the gate. What stops a modified
          // app is the rules refusing the booking itself.
          if (idPending) return null;
          if (!idVerified) {
            const open = {'/commuter/id', '/commuter/profile'};
            return open.contains(loc) ? null : '/commuter/id';
          }
          // Sending a signed-in rider back to sign-in would trap them there.
          if (loc == '/rider-signin') return '/commuter';
          return loc.startsWith('/commuter') ? null : '/commuter';
        case AppRole.driver:
          // Same gate. A dashboard with an Online switch the rules will refuse
          // would be a promise the server does not keep.
          if (idPending) return null;
          if (!idVerified) return loc == '/driver/id' ? null : '/driver/id';
          return loc.startsWith('/driver') ? null : '/driver';
        case AppRole.admin:
          return loc.startsWith('/admin') ? null : '/admin';
        case AppRole.none:
          return onPublic ? null : '/';
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const StaffLoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const DriverRegisterScreen(),
      ),
      GoRoute(
        path: '/rider-signin',
        builder: (_, _) => const RiderSignInScreen(),
      ),
      GoRoute(
        path: '/rider-onboarding',
        builder: (_, _) => const RiderOnboardingScreen(),
      ),
      GoRoute(
        path: '/commuter',
        builder: (_, _) => const CommuterBookingScreen(),
        routes: [
          // Nested, so the redirect's `startsWith('/commuter')` test keeps
          // covering it — the same construction that keeps the admin area
          // admin-only.
          GoRoute(
            path: 'profile',
            builder: (_, _) => const RiderProfileScreen(),
          ),
          GoRoute(
            path: 'id',
            builder: (_, _) =>
                const IdVerificationScreen(role: IdRole.rider),
          ),
        ],
      ),
      GoRoute(
        path: '/driver',
        builder: (_, _) => const DriverDashboardScreen(),
        routes: [
          GoRoute(
            path: 'id',
            builder: (_, _) =>
                const IdVerificationScreen(role: IdRole.driver),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminDashboardScreen(),
        routes: [
          // Nested so the redirect's `startsWith('/admin')` check keeps
          // covering them — an admin-only area stays admin-only by
          // construction rather than by remembering to add each path.
          GoRoute(
            path: 'feedback',
            builder: (_, _) => const FeedbackInboxScreen(),
          ),
          GoRoute(
            path: 'config',
            builder: (_, _) => const ConfigEditorScreen(),
          ),
          GoRoute(
            path: 'ids',
            builder: (_, _) => const IdReviewScreen(),
          ),
        ],
      ),
    ],
  );
});
