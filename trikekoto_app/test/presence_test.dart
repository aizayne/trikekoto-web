import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/notifications/push_service.dart';

/// Going online must never wait on push.
///
/// It used to: the dashboard awaited the push token with no time limit, and
/// `catchError` only handles a failure — a request that never finishes is not
/// one. On a fresh install over a bad network the token request stalled, and
/// the Online switch stayed off with no message at all. A driver in that
/// state cannot tell anything is wrong; they simply never get work.
void main() {
  group('tokenOrNull', () {
    test('a token that never arrives does not hold up going online', () async {
      final never = Completer<String?>().future;
      final clock = Stopwatch()..start();

      final token = await tokenOrNull(never,
          limit: const Duration(milliseconds: 50));

      expect(token, isNull);
      // Generous bound: the point is "returns", not a precise timing.
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a failed token request reads as no token', () async {
      expect(
          await tokenOrNull(Future<String?>.error(Exception('no network'))),
          isNull);
    });

    test('a token that does arrive is kept', () async {
      expect(await tokenOrNull(Future.value('token-1')), 'token-1');
    });

    test('the default wait is short enough to feel like a pause', () {
      // A driver taps a switch and watches it. Past a few seconds that reads
      // as broken, so the ceiling is pinned rather than left to drift.
      expect(pushTokenWait, lessThanOrEqualTo(const Duration(seconds: 8)));
    });
  });
}
