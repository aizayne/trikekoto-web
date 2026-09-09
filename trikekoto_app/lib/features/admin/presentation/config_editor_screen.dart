import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';

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
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Seeds the form once, from whatever the document holds — or from the
  /// compiled defaults when it does not exist yet, which is the normal state
  /// on a fresh project.
  void _seed(DispatchConfig dispatch) {
    if (_loaded) return;
    _loaded = true;
    final values = configDocumentFrom(dispatch);
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: '${entry.value}');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final payload = <String, dynamic>{};
      for (final entry in _fields.entries) {
        payload[entry.key] = num.parse(entry.value.text.trim());
      }

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
    _seed(ref.watch(dispatchConfigProvider));

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
