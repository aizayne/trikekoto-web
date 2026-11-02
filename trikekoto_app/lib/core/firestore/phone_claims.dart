import 'package:cloud_firestore/cloud_firestore.dart';

import 'collection_paths.dart';

/// Reserves a mobile number for one account.
///
/// Written in the same batch as the profile that names the number, because the
/// rules refuse that profile without it. The document ID is the E.164 number,
/// so a second account's write lands on a document it does not own and is
/// refused.
class PhoneClaims {
  const PhoneClaims._();

  static const rider = 'rider';
  static const driver = 'driver';

  static void addTo(
    WriteBatch batch,
    FirebaseFirestore db, {
    required String phone,
    required String uid,
    required String role,
  }) {
    batch.set(db.collection(FsCollections.phoneClaims).doc(phone), {
      'uid': uid,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
