import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/map/landmarks.dart';
import '../../../core/map/location_picker_screen.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';

/// Writes and removes landmarks. A provider so a test can stand in for
/// Firestore.
final landmarkStoreProvider = Provider<LandmarkStore>(LandmarkStore.new);

class LandmarkStore {
  const LandmarkStore(this._ref);
  final Ref _ref;

  CollectionReference<Map<String, dynamic>> get _landmarks =>
      _ref.read(firestoreProvider).collection(FsCollections.landmarks);

  Future<void> add(String name, LatLng point) =>
      _landmarks.add(LandmarkWrites.create(name: name, point: point));

  Future<void> remove(String id) => _landmarks.doc(id).delete();
}

/// The places the chapter has named on the map.
class LandmarksScreen extends ConsumerWidget {
  const LandmarksScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    // Starts at an existing landmark if there is one, so adding several does
    // not mean finding the barangay again each time.
    final existing = ref.read(landmarksProvider).value ?? const <Landmark>[];
    final area = ref.read(serviceAreaProvider).center;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: context.l.lmAdd,
          initialCenter: existing.isNotEmpty
              ? existing.last.point
              : LatLng(area.latitude, area.longitude),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    try {
      await ref.read(landmarkStoreProvider).add(picked.label, picked.point);
      if (context.mounted) showSnack(context, context.l.lmAdded(picked.label));
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, Landmark landmark) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l.lmRemoveQuestion(landmark.name)),
        content: Text(context.l.lmRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(context.l.fbDeleteNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(context.l.fbDelete),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;

    try {
      await ref.read(landmarkStoreProvider).remove(landmark.id);
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(landmarksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l.adminLandmarks)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(context.l.lmAdd),
      ),
      body: SafeArea(
        child: landmarks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(describeError(e), textAlign: TextAlign.center),
            ),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.flag_circle_outlined,
                    title: context.l.lmEmptyTitle,
                    body: context.l.lmEmptyBody,
                  ),
                )
              : ListView.separated(
                  // Clear of the add button, so the last row can be reached.
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(Icons.flag_circle,
                        color: context.scheme.secondary),
                    title: Text(list[i].name),
                    trailing: IconButton(
                      tooltip: context.l.fbDelete,
                      icon: Icon(Icons.delete_outline,
                          color: context.scheme.error),
                      onPressed: () => _remove(context, ref, list[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
