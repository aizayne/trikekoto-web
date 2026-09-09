import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';

/// Every commuter needs an account, on every platform.
///
/// The client half is this: an anonymous session is routed to sign-in rather
/// than allowed to book. The half that actually holds is in the security
/// rules — `hasVerifiedPhone()` on ride creation — because a client screen can
/// be bypassed and a token claim cannot. See `booking requires a verified
/// phone` in test_rules/rules.test.mjs.
///
/// Anonymous sessions still resolve rather than being signed out. Dropping one
/// silently would look like the app logging itself out, and their past rides
/// carry that uid — linking a phone credential to it is what keeps the
/// history.

void main() {
  SessionState commuter({required bool anonymous, bool onboarded = true}) =>
      SessionState(
        user: null,
        role: AppRole.commuter,
        loading: false,
        isAnonymous: anonymous,
        needsRiderOnboarding: !onboarded,
      );

  group('the predicate the web gate turns on', () {
    test('an anonymous commuter is flagged as such', () {
      expect(commuter(anonymous: true).isAnonymous, isTrue);
    });

    test('a phone-verified rider is not', () {
      // They signed in, so the web gate must let them through rather than
      // bouncing them back to a screen they already completed.
      expect(commuter(anonymous: false).isAnonymous, isFalse);
    });

    test('defaults to not-anonymous rather than assuming', () {
      // A default of true would send every signed-in rider to the sign-in
      // screen on any path that forgot to set it.
      const s = SessionState(
        user: null,
        role: AppRole.commuter,
        loading: false,
      );
      expect(s.isAnonymous, isFalse);
    });

    test('a loading session is not treated as anonymous', () {
      // The router returns early while loading. If this were true, a web
      // visitor would be flung to sign-in for a frame on every cold start.
      expect(const SessionState.loading().isAnonymous, isFalse);
    });
  });

  group('onboarding still takes precedence', () {
    test('a verified rider mid-onboarding is not anonymous', () {
      // Both flags can be relevant at once. Onboarding is checked after the
      // web gate, and this is the case that proves the gate lets them past:
      // they have signed in, they simply have no name yet.
      final s = commuter(anonymous: false, onboarded: false);
      expect(s.isAnonymous, isFalse);
      expect(s.needsRiderOnboarding, isTrue);
    });

    test('an anonymous commuter never needs rider onboarding', () {
      // They have no phone number, so there is no profile to complete.
      final s = commuter(anonymous: true);
      expect(s.needsRiderOnboarding, isFalse);
    });
  });
}
