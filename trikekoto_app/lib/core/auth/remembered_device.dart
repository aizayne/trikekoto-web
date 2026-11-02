import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What lets this phone sign back in to one commuter account without a code.
class RememberedDevice {
  const RememberedDevice({
    required this.uid,
    required this.phone,
    required this.secret,
  });

  final String uid;
  final String phone;
  final String secret;

  /// Enough to recognise the number, for someone else who picks up the phone.
  String get maskedPhone => phone.length <= 7
      ? phone
      : '${phone.substring(0, 3)}•••••••${phone.substring(phone.length - 4)}';

  String encode() => jsonEncode({'uid': uid, 'phone': phone, 'secret': secret});

  /// Null for anything unreadable, which only means a code is needed.
  static RememberedDevice? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return RememberedDevice(
        uid: m['uid'] as String,
        phone: m['phone'] as String,
        secret: m['secret'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Keeps the secret in the Android Keystore's protection.
///
/// A failure here must never get in the way of signing in, so reads and writes
/// that fail behave as though this phone is not remembered. App backup is
/// switched off in the manifest, so a restored phone does not inherit this.
class RememberedDeviceStore {
  const RememberedDeviceStore();

  static const _key = 'remembered_device';
  static const _storage = FlutterSecureStorage();

  Future<RememberedDevice?> read() async {
    // A browser cannot keep this safely, so the web build always uses a code.
    if (kIsWeb) return null;
    try {
      return RememberedDevice.decode(await _storage.read(key: _key));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RememberedDevice device) =>
      _storage.write(key: _key, value: device.encode());

  Future<void> clear() => _storage.delete(key: _key);
}

final rememberedDeviceStoreProvider =
    Provider<RememberedDeviceStore>((ref) => const RememberedDeviceStore());

/// The account this phone can sign back in to, if any.
final rememberedDeviceProvider = FutureProvider<RememberedDevice?>(
  (ref) => ref.watch(rememberedDeviceStoreProvider).read(),
);
