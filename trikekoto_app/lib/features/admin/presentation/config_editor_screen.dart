import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../../../core/map/location_picker_screen.dart';

/// Edits `config/app` — the dispatch settings every client reads.
///
/// This exists because the APK reaches drivers as a file over Wi-Fi, not
/// through an update channel. Without it, widening the search radius or
/// lengthening the offer timeout would mean rebuilding and redistributing to
/// every driver; here it takes effect on running clients within seconds.
class ConfigEditorScreen extends ConsumerStatefulWidget {
  const ConfigEditorScreen({super.key});

  @override
  ConsumerState<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends ConsumerState<ConfigEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};

  /// The service area is edited apart from the numeric fields: it carries a
  /// name and a point, and [_save] parses everything in [_fields] as a number.
  final _areaLabel = TextEditingController();
  GeoPoint? _areaCenter;

  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _areaLabel.dispose();
    super.dispose();
  }

  /// Seeds the form once, from whatever the document holds — or from the
  /// compiled defaults when it does not exist yet, which is the normal state
  /// on a fresh project.
  void _seed(DispatchConfig dispatch, ServiceArea area) {
    if (_loaded) return;
    _loaded = true;
    final values = configDocumentFrom(dispatch);
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: '${entry.value}');
    }
    _fields['serviceAreaRadiusKm'] =
        TextEditingController(text: '${area.radiusKm}');
    _areaLabel.text = area.label;
    _areaCenter = area.center;
  }

  /// Picks the centre of the area on the same map commuters set a pickup on.
  Future<void> _pickCentre() async {
    final here = _areaCenter ?? ServiceArea.fallback.center;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: context.l.cfgAreaSetCenter,
          initialCenter: LatLng(here.latitude, here.longitude),
          initialLabel: _areaLabel.text,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _areaCenter = GeoPoint(picked.point.latitude, picked.point.longitude);
      if (_areaLabel.text.trim().isEmpty) _areaLabel.text = picked.label;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final payload = <String, dynamic>{};
      for (final entry in _fields.entries) {
        if (entry.key == 'serviceAreaRadiusKm') continue;
        payload[entry.key] = num.parse(entry.value.text.trim());
      }

      final centre = _areaCenter ?? ServiceArea.fallback.center;
      final label = _areaLabel.text.trim();
      payload['serviceArea'] = ServiceArea(
        label: label.isEmpty ? ServiceArea.fallback.label : label,
        center: centre,
        radiusKm:
            num.parse(_fields['serviceAreaRadiusKm']!.text.trim()).toDouble(),
      ).toMap();

      // merge:true creates the document on first save and leaves any key this
      // screen does not manage — minAppVersion, for one — untouched.
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.config)
          .doc(FsCollections.configAppDoc)
          .set(payload, SetOptions(merge: true));

      if (mounted) showSnack(context, context.l.cfgSaved);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _seed(ref.watch(dispatchConfigProvider), ref.watch(serviceAreaProvider));

    return Scaffold(
      appBar: AppBar(title: Text(context.l.cfgTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Explainer(
                context.l.cfgIntro,
              ),
              const Gap(AppSpacing.xxl),

              const _BookingSwitch(),
              const Gap(AppSpacing.xxl),

              Text(context.l.cfgMatching, style: context.text.titleMedium),
              const Gap(AppSpacing.md),
              _numberField(
                'searchRadiusKm',
                context.l.cfgRadiusLabel,
                context.l.cfgRadiusHelp,
                min: 0.5,
                max: 50,
              ),
              const Gap(AppSpacing.md),
              _numberField(
                'offerTimeoutSeconds',
                context.l.cfgTimeoutLabel,
                context.l.cfgTimeoutHelp,
                min: 5,
                max: 120,
                integer: true,
              ),
              const Gap(AppSpacing.md),
              _numberField(
                'maxDriversToTry',
                context.l.cfgMaxDriversLabel,
                context.l.cfgMaxDriversHelp,
                min: 1,
                max: DispatchDefaults.maxDriversToTry.toDouble(),
                integer: true,
              ),

              const Gap(AppSpacing.xxl),
              Text(context.l.cfgAreaTitle, style: context.text.titleMedium),
              const Gap(AppSpacing.md),
              _Explainer(context.l.cfgAreaIntro),
              const Gap(AppSpacing.md),
              TextFormField(
                controller: _areaLabel,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.l.cfgAreaLabel,
                  helperText: context.l.cfgAreaLabelHelp,
                ),
              ),
              const Gap(AppSpacing.md),
              _numberField(
                'serviceAreaRadiusKm',
                context.l.cfgAreaRadiusLabel,
                context.l.cfgAreaRadiusHelp,
                min: 0,
                max: 100,
              ),
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l.cfgAreaCenter(
                        (_areaCenter ?? ServiceArea.fallback.center)
                            .latitude
                            .toStringAsFixed(5),
                        (_areaCenter ?? ServiceArea.fallback.center)
                            .longitude
                            .toStringAsFixed(5),
                      ),
                      style: context.text.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _pickCentre,
                    icon: const Icon(Icons.map_outlined,
                        size: AppSpacing.iconSm),
                    label: Text(context.l.cfgAreaSetCenter),
                  ),
                ],
              ),

              const Gap(AppSpacing.xxl),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: AppSpacing.iconSm,
                        height: AppSpacing.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Text(context.l.cfgSaveSettings),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    String key,
    String label,
    String helper, {
    required double min,
    required double max,
    bool integer = false,
  }) {
    final controller = _fields.putIfAbsent(key, TextEditingController.new);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(labelText: label, helperText: helper),
      // Bounds are enforced here as well as in the parser, because a typo in
      // this form changes behaviour for every driver at once.
      validator: (v) {
        final parsed = num.tryParse((v ?? '').trim());
        if (parsed == null) return 'Enter a number';
        if (integer && parsed != parsed.roundToDouble()) {
          return 'Whole numbers only';
        }
        if (parsed < min || parsed > max) return 'Must be between $min and $max';
        return null;
      },
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune,
              size: AppSpacing.iconSm,
              color: context.scheme.onSecondaryContainer),
          const Gap(AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pilot stop button.
///
/// Saves the instant it is flipped rather than waiting for the form's Save,
/// because the situation it exists for is one where every second of continued
/// booking is a passenger you have to apologise to.
///
/// Stopping asks for confirmation; resuming does not. Getting stuck stopped is
/// a far worse failure than an accidental resume.
class _BookingSwitch extends ConsumerStatefulWidget {
  const _BookingSwitch();

  @override
  ConsumerState<_BookingSwitch> createState() => _BookingSwitchState();
}

class _BookingSwitchState extends ConsumerState<_BookingSwitch> {
  bool _busy = false;

  Future<void> _set(bool accepting) async {
    if (!accepting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l.cfgStopQuestion),
          content: Text(
            context.l.cfgStopBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l.cfgCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l.cfgStopBookings),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.config)
          .doc(FsCollections.configAppDoc)
          .set({'acceptingRides': accepting}, SetOptions(merge: true));

      if (mounted) {
        showSnack(
          context,
          accepting
              ? context.l.cfgResumed
              : context.l.cfgStopped,
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepting = ref.watch(acceptingRidesProvider);

    return Card(
      color: accepting ? null : context.semantic.dangerContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  accepting ? Icons.play_circle_outline : Icons.pause_circle_outline,
                  color: accepting
                      ? context.semantic.success
                      : context.semantic.danger,
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Text(
                    accepting
                        ? context.l.cfgAccepting
                        : context.l.cfgStoppedLabel,
                    style: context.text.titleMedium,
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: AppSpacing.iconSm,
                    height: AppSpacing.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: accepting, onChanged: _set),
              ],
            ),
            const Gap(AppSpacing.sm),
            Text(
              accepting
                  ? context.l.cfgAcceptingHelp
                  : context.l.cfgStoppedHelp,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
