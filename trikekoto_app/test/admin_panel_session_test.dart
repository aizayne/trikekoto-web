import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/firestore/firestore_refs.dart';
import 'package:trikekoto_app/core/providers.dart';
import 'package:trikekoto_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/identity/data/id_submission.dart';

/// Signing out while the admin panel is open makes its open queries fail, because
/// the rules no longer recognise the reader. These providers did not follow the
/// session, so they kept that failure: signing back in showed "The server refused
/// that action", on a working admin account, until the page was reloaded.
class _User extends Fake implements User {
  _User(this.uid);

  @override
  final String uid;
}

class _Session extends SessionController {
  @override
  SessionState build() => SessionState(
      user: _User('admin'), role: AppRole.admin, loading: false);

  void signOutNow() => state =
      const SessionState(user: null, role: AppRole.none, loading: false);

  void signIn() => state = SessionState(
      user: _User('admin'), role: AppRole.admin, loading: false);
}

class _Snapshot extends Fake implements QuerySnapshot<Driver> {
  @override
  List<QueryDocumentSnapshot<Driver>> get docs => const [];
}

// ignore: subtype_of_sealed_class
class _Drivers extends Fake implements CollectionReference<Driver> {
  final streams = <StreamController<QuerySnapshot<Driver>>>[];

  @override
  Stream<QuerySnapshot<Driver>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final stream = StreamController<QuerySnapshot<Driver>>();
    streams.add(stream);
    return stream.stream;
  }
}

class _Refs extends Fake implements FirestoreRefs {
  _Refs(this.drivers);

  @override
  final CollectionReference<Driver> drivers;
}

class _Service extends Fake implements IdVerificationService {
  final streams = <StreamController<List<IdSubmission>>>[];

  @override
  Stream<List<IdSubmission>> watchPending() {
    final stream = StreamController<List<IdSubmission>>();
    streams.add(stream);
    return stream.stream;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;
  late _Session session;
  late _Drivers drivers;
  late _Service service;
  final refused = FirebaseException(plugin: 'x', code: 'permission-denied');

  setUp(() {
    session = _Session();
    drivers = _Drivers();
    service = _Service();
    container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      refsProvider.overrideWithValue(_Refs(drivers)),
      idVerificationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    // Held open, as the router does, so the session outlives each query.
    container.listen(sessionProvider, (_, _) {});
  });

  test('a refusal from signing out does not outlast the sign-out', () async {
    final sub = container.listen(allDriversProvider, (_, _) {});
    await _settle();

    drivers.streams.last.addError(refused);
    session.signOutNow();
    await _settle();

    session.signIn();
    await _settle();
    expect(container.read(allDriversProvider).hasError, isFalse);

    drivers.streams.last.add(_Snapshot());
    await _settle();
    expect(container.read(allDriversProvider).value, isEmpty);
    sub.close();
  });

  test('the same when the panel closed before the refusal arrived', () async {
    final sub = container.listen(allDriversProvider, (_, _) {});
    await _settle();

    sub.close();
    drivers.streams.last.addError(refused);
    session.signOutNow();
    await _settle();

    session.signIn();
    container.listen(allDriversProvider, (_, _) {});
    await _settle();
    expect(container.read(allDriversProvider).hasError, isFalse);
  });

  test('the ID queue starts over too', () async {
    container.listen(pendingIdSubmissionsProvider, (_, _) {});
    await _settle();

    service.streams.last.addError(refused);
    session.signOutNow();
    await _settle();

    session.signIn();
    await _settle();
    expect(container.read(pendingIdSubmissionsProvider).hasError, isFalse);
  });

  test('nothing is asked for while signed out', () async {
    container.listen(allDriversProvider, (_, _) {});
    await _settle();
    final asked = drivers.streams.length;

    session.signOutNow();
    await _settle();
    expect(drivers.streams.length, asked);
  });
}
