import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../data/id_submission.dart';
import '../../../core/auth/session_controller.dart';

/// Submitting and reviewing government IDs.
///
/// The image handling differs deliberately from the profile-photo service, in
/// one way that matters: **nothing here ever calls `getDownloadURL()`**.
///
/// A download URL carries an access token that bypasses the Storage rules
/// entirely. Anyone holding the string can fetch the object, from anywhere,
/// and it keeps working after the submission is deleted. That is a reasonable
/// trade for a profile picture the driver is meant to see anyway. It is the
/// wrong trade for a government ID, where the whole point is that exactly two
/// parties may look at it.
///
/// So the reviewer reads bytes with [reviewerImage], which stays subject to
/// the Storage rules on every call and mints no shareable link.
class IdVerificationService {
  IdVerificationService(this._db, this._storage, this._picker);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Longest edge after downscaling.
  ///
  /// Larger than a profile photo, because a reviewer has to read a number off
  /// the card. Still bounded, because a 12-megapixel original would be slow
  /// on the mobile data a commuter is paying for and would push against the
  /// 4 MB cap in the Storage rules.
  static const _maxEdge = 1600.0;
  static const _quality = 85;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FsCollections.idSubmissions).doc(uid);

  Reference _image(String uid) => _storage.ref(IdPaths.card(uid));

  /// Picks a photo of the card and returns its bytes.
  ///
  /// Returns null when the person backs out, which is an ordinary outcome and
  /// must not be reported as a failure.
  Future<Uint8List?> pick({required ImageSource source}) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Uploads the card, then writes the submission.
  ///
  /// Image first, document second — the reverse of onboarding, and for the
  /// opposite reason. Onboarding writes the profile first so a failed upload
  /// still leaves a usable account. Here a submission with no image is not
  /// usable: it would sit in the review queue as a record an admin cannot act
  /// on, and it would already be the sensitive-data liability. Better to fail
  /// before anything is recorded.
  Future<void> submit({
    required String uid,
    required String role,
    required String idType,
    required String idNumber,
    required Uint8List photoBytes,
  }) async {
    await _image(uid).putData(
      photoBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        // Never cached by an intermediary. The rules decide who may read
        // this on every request, and a cache would answer some of them
        // without asking.
        cacheControl: 'no-store',
      ),
    );

    await _doc(uid).set(IdSubmissionWrites.create(
      subjectUid: uid,
      role: role,
      idType: idType,
      idNumber: idNumber,
    ));
  }

  /// The subject's own submission, or null if they have not made one.
  Stream<IdSubmission?> watchMine(String uid) => _doc(uid).snapshots().map(
        (snap) => snap.exists ? IdSubmission.fromSnapshot(snap) : null,
      );

  /// The review queue, oldest first — the order a person waiting would
  /// consider fair.
  Stream<List<IdSubmission>> watchPending() => _db
      .collection(FsCollections.idSubmissions)
      .where('status', isEqualTo: IdStatus.pending)
      .orderBy('submittedAt')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(IdSubmission.fromSnapshot).toList());

  /// The card image, for a reviewer, as bytes.
  ///
  /// Deliberately not a URL. See the class note — this call is checked against
  /// the Storage rules every time and leaves nothing behind that would still
  /// work once the submission is gone.
  ///
  /// Capped at 8 MB, above the 4 MB the rules admit, so a legitimate image
  /// always fits and a tampered-with object cannot exhaust memory.
  Future<Uint8List?> reviewerImage(String uid) =>
      _image(uid).getData(8 * 1024 * 1024);

  Future<void> approve({
    required String uid,
    required String reviewerEmail,
  }) =>
      _doc(uid).update(
        IdSubmissionWrites.approve(reviewerEmail: reviewerEmail),
      );

  Future<void> reject({
    required String uid,
    required String reviewerEmail,
    required String reason,
  }) =>
      _doc(uid).update(
        IdSubmissionWrites.reject(
          reviewerEmail: reviewerEmail,
          reason: reason,
        ),
      );

  /// Removes the submission and the image together.
  ///
  /// Both, always. Deleting the document alone would leave the ID photo in
  /// the bucket with nothing pointing at it — invisible in every screen, and
  /// still very much personal data being retained.
  ///
  /// A missing object is success: the caller wants there to be no image, and
  /// there is none.
  Future<void> withdraw(String uid) async {
    try {
      await _image(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
    await _doc(uid).delete();
  }
}

final idVerificationServiceProvider = Provider<IdVerificationService>((ref) {
  return IdVerificationService(
    ref.watch(firestoreProvider),
    FirebaseStorage.instance,
    ImagePicker(),
  );
});

/// The signed-in person's own submission, whichever role they hold.
final myIdSubmissionProvider = StreamProvider<IdSubmission?>((ref) {
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(idVerificationServiceProvider)
      .watchMine(uid)
      // Not having submitted is the normal case and reads as null, not as an
      // error the screen has to explain.
      .handleError((_) {})
      .cast<IdSubmission?>();
});

/// The admin review queue.
final pendingIdSubmissionsProvider =
    StreamProvider<List<IdSubmission>>((ref) {
  return ref.watch(idVerificationServiceProvider).watchPending();
});

/// Whether the signed-in person's ID has been approved.
///
/// Reads `id_verified/{uid}`, never the submission. Retention deletes the
/// submission after 90 days; the marker stays, and it is what the security
/// rules check — so this is what the router must check too, or the app and
/// the server would disagree about who is allowed in.
///
/// Keyed on the session's uid rather than `currentUser`, so it re-subscribes
/// when a different person signs in on the same phone.
final myIdVerifiedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.uid));
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection(FsCollections.idVerified)
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists);
});
