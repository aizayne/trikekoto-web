import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/identity/data/id_submission.dart';

/// A phone is handed from one account to the next without the app restarting.
///
/// These providers once read `currentUser` off the auth provider, which never
/// changes, so they stayed on whoever signed in first. A new driver's ID screen
/// then showed the previous driver's approved ID: "Verified", under a notice
/// saying a verified ID was required.
class _User extends Fake implements User {
  _User(this.uid, this.email);

  @override
  final String uid;

  @override
  final String? email;
}

class _Session extends SessionController {
  @override
  SessionState build() =>
      const SessionState(user: null, role: AppRole.none, loading: false);

  void signIn(User? user) => state = SessionState(
        user: user,
        role: user == null ? AppRole.none : AppRole.driver,
        loading: false,
      );
}

class _Service extends Fake implements IdVerificationService {
  _Service(this.byUid);
  final Map<String, IdSubmission?> byUid;

  @override
  Stream<IdSubmission?> watchMine(String uid) => Stream.value(byUid[uid]);
}

class _Submission extends Fake implements IdSubmission {}

void main() {
  late ProviderContainer container;
  late _Session session;
  final approved = _Submission();

  setUp(() {
    session = _Session();
    container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => session),
      idVerificationServiceProvider
          .overrideWithValue(_Service({'first': approved})),
    ]);
    addTearDown(container.dispose);
  });

  Future<IdSubmission?> submissionNow() async {
    await Future<void>.delayed(Duration.zero);
    return container.read(myIdSubmissionProvider).value;
  }

  test('a new account does not see the previous account\'s ID', () async {
    // Listened to throughout, as the open app is, or it would simply be paused.
    container.listen(myIdSubmissionProvider, (_, _) {});

    session.signIn(_User('first', 'first@toda.ph'));
    expect(await submissionNow(), same(approved));

    session.signIn(null);
    expect(await submissionNow(), isNull);

    session.signIn(_User('second', 'second@toda.ph'));
    expect(await submissionNow(), isNull);
  });

  test('switching directly between accounts moves the ID too', () async {
    container.listen(myIdSubmissionProvider, (_, _) {});

    session.signIn(_User('first', 'first@toda.ph'));
    expect(await submissionNow(), same(approved));

    session.signIn(_User('second', 'second@toda.ph'));
    expect(await submissionNow(), isNull);
  });

  test('the driver identity follows the signed-in account', () {
    container.listen(driverEmailProvider, (_, _) {});

    session.signIn(_User('first', 'First@toda.ph'));
    expect(container.read(driverEmailProvider), 'first@toda.ph');

    session.signIn(_User('second', 'second@toda.ph'));
    expect(container.read(driverEmailProvider), 'second@toda.ph');

    session.signIn(null);
    expect(container.read(driverEmailProvider), '');
  });
}
