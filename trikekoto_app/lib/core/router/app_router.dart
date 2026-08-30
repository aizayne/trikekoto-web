import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/config_editor_screen.dart';
import '../../features/admin/presentation/feedback_inbox_screen.dart';
import '../../features/commuter/presentation/commuter_booking_screen.dart';
import '../../features/drivers/presentation/driver_dashboard_screen.dart';
import '../../features/drivers/presentation/driver_register_screen.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/landing/presentation/staff_login_screen.dart';
import '../auth/session_controller.dart';

/// Role-based routing.
///
/// The redirect is the only place that decides which shell a user lands in, so
/// there is no way to reach the admin panel by deep link without the role to
/// back it up — and even if there were, the rules would refuse the reads.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.loading) return null;

      final signedIn = session.isSignedIn;
      final onPublic = loc == '/' || loc == '/login' || loc == '/register';

      if (!signedIn) return onPublic ? null : '/';

      switch (session.role) {
        case AppRole.commuter:
          return loc.startsWith('/commuter') ? null : '/commuter';
        case AppRole.driver:
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
        path: '/commuter',
        builder: (_, _) => const CommuterBookingScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (_, _) => const DriverDashboardScreen(),
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
        ],
      ),
    ],
  );
});
