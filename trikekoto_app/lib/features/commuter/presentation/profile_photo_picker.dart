import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../application/profile_photo_service.dart';

/// A tappable avatar that picks a photo and hands back the bytes.
///
/// Deliberately does not upload. The bytes are held until the rider commits —
/// onboarding writes the document and the photo together, so backing out
/// leaves no orphaned object in the bucket paid for by an account that was
/// never created.
class ProfilePhotoPicker extends ConsumerStatefulWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.onChanged,
    this.existingUrl,
    this.enabled = true,
  });

  /// Fires with the chosen bytes, or null when the rider removes the photo.
  final void Function(Uint8List? bytes) onChanged;

  /// Shown until the rider picks something new.
  final String? existingUrl;

  final bool enabled;

  @override
  ConsumerState<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends ConsumerState<ProfilePhotoPicker> {
  Uint8List? _picked;
  bool _busy = false;

  bool get _hasPhoto => _picked != null || widget.existingUrl != null;

  Future<void> _choose(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(profilePhotoServiceProvider).pick(source: source);
      // Null means they backed out of the picker. Not an error, and
      // reporting it as one would be noise on a perfectly normal action.
      if (bytes == null) return;
      if (!mounted) return;
      setState(() => _picked = bytes);
      widget.onChanged(bytes);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() => _picked = null);
    widget.onChanged(null);
  }

  Future<void> _openSheet() async {
    if (!widget.enabled || _busy) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l.photoTake),
              onTap: () {
                Navigator.pop(sheet);
                _choose(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l.photoGallery),
              onTap: () {
                Navigator.pop(sheet);
                _choose(ImageSource.gallery);
              },
            ),
            if (_hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: context.scheme.error),
                title: Text(context.l.photoRemove,
                    style: TextStyle(color: context.scheme.error)),
                onTap: () {
                  Navigator.pop(sheet);
                  _clear();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _hasPhoto ? context.l.photoChange : context.l.photoAdd,
      child: InkWell(
        onTap: _openSheet,
        customBorder: const CircleBorder(),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: context.scheme.secondaryContainer,
              foregroundImage: _picked != null
                  ? MemoryImage(_picked!)
                  : (widget.existingUrl != null
                      ? NetworkImage(widget.existingUrl!)
                      : null) as ImageProvider?,
              child: _busy
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : (_hasPhoto
                      ? null
                      : Icon(Icons.person_outline,
                          size: 44,
                          color: context.scheme.onSecondaryContainer)),
            ),
            // A camera badge, because a bare avatar does not read as
            // something you can tap.
            if (widget.enabled && !_busy)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.scheme.primary,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: context.scheme.surface, width: 2),
                ),
                child: Icon(
                  _hasPhoto ? Icons.edit : Icons.add_a_photo_outlined,
                  size: 16,
                  color: context.scheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
