import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore/firestore_refs.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Every query in the app goes through here — see the note in
/// [FirestoreRefs] about why queries are not built inline.
final refsProvider =
    Provider<FirestoreRefs>((ref) => FirestoreRefs(ref.watch(firestoreProvider)));

/// The region the Cloud Functions are deployed to.
///
/// Must match `REGION` in `functions/src/index.ts`. Getting this wrong does
/// not fail at build time — it fails at call time with a `not-found`, because
/// the SDK cheerfully calls a function that exists nowhere.
const functionsRegion = 'asia-southeast1';

final functionsProvider = Provider<FirebaseFunctions>(
    (ref) => FirebaseFunctions.instanceFor(region: functionsRegion));

/// Advances the caller's own searching ride by one step: the server picks the
/// next nearest driver and writes the offer.
///
/// This replaced a client-side query over `active_drivers`. See
/// `DispatchController` for why, and `canDiscoverDrivers()` in
/// `firestore.rules` for what it bought.
final dispatchCallableProvider = Provider<HttpsCallable>(
    (ref) => ref.watch(functionsProvider).httpsCallable('requestDispatch'));
