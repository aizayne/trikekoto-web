import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../drivers/application/driver_controllers.dart'
    show driverEmailProvider;
import '../data/ride.dart';

/// Who is looking at a ride history.
///
/// Decides the query — the rules admit each audience a different slice of
/// `rides` — and what each row says about the other party.
enum HistoryAudience { commuter, driver, admin }

/// Rides a history screen asks for at a time.
///
/// Each ride listed bills one read, and a live listener re-reads nothing but
/// does hold every listed document. A page rather than everything keeps a
/// chapter's months of rides from being fetched whenever someone looks.
const historyPageSize = 30;

class HistoryLimit extends Notifier<int> {
  @override
  int build() => historyPageSize;

  void more() => state += historyPageSize;
}

/// How many rides the open history screen shows. One screen is open at a
/// time, so one counter serves all three audiences.
final historyLimitProvider =
    NotifierProvider.autoDispose<HistoryLimit, int>(HistoryLimit.new);

/// The admin's status filter. Null shows every ride.
class HistoryFilter extends Notifier<RideStatus?> {
  @override
  RideStatus? build() => null;

  void set(RideStatus? status) => state = status;
}

final adminHistoryFilterProvider =
    NotifierProvider.autoDispose<HistoryFilter, RideStatus?>(HistoryFilter.new);

/// The rides [audience] may see, newest first.
final rideHistoryProvider = StreamProvider.autoDispose
    .family<List<Ride>, HistoryAudience>((ref, audience) {
  final refs = ref.watch(refsProvider);
  final limit = ref.watch(historyLimitProvider);

  final Query<Ride>? query = switch (audience) {
    HistoryAudience.commuter => () {
        final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
        return uid == null ? null : refs.ridesForCommuter(uid);
      }(),
    HistoryAudience.driver => () {
        final email = ref.watch(driverEmailProvider);
        return email.isEmpty ? null : refs.rideHistoryFor(email);
      }(),
    HistoryAudience.admin =>
      refs.recentRides(status: ref.watch(adminHistoryFilterProvider)),
  };

  if (query == null) return Stream.value(const <Ride>[]);
  return query
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});
