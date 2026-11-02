import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/router/app_router.dart';

/// Nobody books or works without an approved ID.
///
/// The rules are what hold against a modified app. This is the half an honest
/// app obeys: an unverified person must not be shown a screen the server will
/// then refuse.
class _User extends Fake implements User {}

SessionState _session(AppRole role) =>
    SessionState(user: _User(), role: role, loading: false);

void main() {
  const verified = AsyncData<bool>(true);
  const unverified = AsyncData<bool>(false);

  group('an unverified person', () {
    test('a commuter is sent to the ID screen from everywhere else', () {
      for (final loc in ['/', '/rider-signin', '/commuter', '/commuter/history']) {
        expect(
          gateRedirect(
              session: _session(AppRole.commuter),
              idCheck: unverified,
              loc: loc),
          '/commuter/id',
          reason: loc,
        );
      }
    });

    test('a commuter can still reach their profile, to delete the account', () {
      expect(
        gateRedirect(
            session: _session(AppRole.commuter),
            idCheck: unverified,
            loc: '/commuter/profile'),
        isNull,
      );
    });

    test('a driver is sent to the ID screen from everywhere else', () {
      for (final loc in ['/', '/login', '/driver', '/driver/history']) {
        expect(
          gateRedirect(
              session: _session(AppRole.driver),
              idCheck: unverified,
              loc: loc),
          '/driver/id',
          reason: loc,
        );
      }
    });

    test('an admin is not gated, because admins hold no ride or shift', () {
      expect(
        gateRedirect(
            session: _session(AppRole.admin),
            idCheck: unverified,
            loc: '/admin'),
        isNull,
      );
    });
  });

  test('a verified person goes through', () {
    expect(
      gateRedirect(
          session: _session(AppRole.commuter),
          idCheck: verified,
          loc: '/commuter/id'),
      isNull,
    );
    expect(
      gateRedirect(
          session: _session(AppRole.driver), idCheck: verified, loc: '/login'),
      '/driver',
    );
  });

  test('no answer yet leaves the person where they are', () {
    expect(
      gateRedirect(
          session: _session(AppRole.driver),
          idCheck: const AsyncLoading<bool>(),
          loc: '/login'),
      isNull,
    );
  });

  group('an old "verified" is not believed', () {
    late StreamController<bool> marker;
    late ProviderContainer container;
    late StreamProvider<bool> check;

    setUp(() async {
      marker = StreamController<bool>.broadcast();
      check = StreamProvider<bool>((ref) => marker.stream, retry: (_, _) => null);
      container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(marker.close);
      container.listen(check, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      marker.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(check).value, isTrue);
    });

    test('an error reads as unverified, even with a value still held', () async {
      marker.addError(StateError('permission-denied'));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(check);
      expect(state.hasError, isTrue);
      expect(state.value, isTrue, reason: 'Riverpod keeps the last value');
      expect(
        gateRedirect(
            session: _session(AppRole.driver), idCheck: state, loc: '/driver'),
        '/driver/id',
      );
    });

    test('a reload waits, rather than trusting the previous answer', () async {
      container.invalidate(check);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(check);
      expect(state.isLoading, isTrue);
      expect(state.value, isTrue, reason: 'Riverpod keeps the last value');
      expect(
        gateRedirect(
            session: _session(AppRole.driver), idCheck: state, loc: '/login'),
        isNull,
      );
    });
  });
}
