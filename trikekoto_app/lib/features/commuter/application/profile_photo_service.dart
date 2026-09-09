import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Uploading a rider's profile photo.
///
/// The photo lives at a fixed path per rider — `riders/{uid}/profile` — rather
/// than under a name the rider supplies. One object per person means a second
/// upload replaces the first instead of accumulating orphans nobody deletes,
/// and there is no filename for a modified client to play `../` games with.
class ProfilePhotoService {
  ProfilePhotoService(this._storage, this._picker);

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// The longest edge, in pixels, after resizing.
  ///
  /// A profile photo is rendered at about 96 px. 512 leaves room for a
  /// high-density screen and still turns a 4 MB camera file into something
  /// around 40 KB — which matters when it is uploaded over mobile data the
  /// rider is paying for.
  static const _maxEdge = 512.0;

  /// JPEG quality. 80 is the point past which more bytes stop being visible
  /// at this size.
  static const _quality = 80;

  Reference _ref(String uid) => _storage.ref('riders/$uid/profile');

  /// Picks an image and returns its bytes, already resized.
  ///
  /// Resizing happens in the picker rather than after: it is done natively,
  /// so a large photo never has to be decoded into Dart memory — which is
  /// where a low-end handset would run out.
  ///
  /// Returns null when the rider backs out of the picker, which is not an
  /// error and must not be reported as one.
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

  /// Uploads and returns the download URL to store on the rider document.
  ///
  /// The content type is set explicitly. Without it Storage serves
  /// `application/octet-stream`, which browsers download rather than display —
  /// the photo would upload successfully and then never render.
  Future<String> upload({required String uid, required Uint8List bytes}) async {
    final ref = _ref(uid);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        // Photos change rarely and are fetched on every profile view.
        cacheControl: 'public, max-age=86400',
      ),
    );
    return ref.getDownloadURL();
  }

  /// Removes the photo.
  ///
  /// A missing object is success, not failure: the caller wants there to be no
  /// photo, and there is none.
  Future<void> remove(String uid) async {
    try {
      await _ref(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

final profilePhotoServiceProvider = Provider<ProfilePhotoService>(
  (ref) => ProfilePhotoService(FirebaseStorage.instance, ImagePicker()),
);
