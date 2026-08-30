import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fare/fare_calculator.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';

/// Edits `config/app` — the dispatch and fare settings every client reads.
///
/// This exists because the APK reaches drivers as a file over Wi-Fi, not
/// through an update channel. Without it, re-tariffing a chapter or widening
/// the search radius would mean rebuilding and redistributing to every
/// driver; here it takes effect on running clients within seconds.
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
  void _seed(DispatchConfig dispatch, FareConfig fare) {
    if (_loaded) return;
    _loaded = true;
    final values = configDocumentFrom(dispatch, fare);
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

      if (mounted) showSnack(context, 'Settings saved. Clients update live.');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _seed(ref.watch(dispatchConfigProvider), ref.watch(fareConfigProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch & fares')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const _Explainer(
                'These values live on the server. Changing them takes effect '
                'on every phone within seconds — no new app version needed.',
              ),
              const Gap(AppSpacing.xxl),

              const _BookingSwitch(),
              const Gap(AppSpacing.xxl),

              Text('Matching', style: context.text.titleMedium),
              const Gap(AppSpacing.md),
              _numberField(
                'searchRadiusKm',
                'Search radius (km)',
                'Drivers further than this are never offered the ride.',
                min: 0.5,
                max: 50,
              ),
              const Gap(AppSpacing.md),
              _numberField(
                'offerTimeoutSeconds',
                'Offer timeout (seconds)',
                'How long one driver has to answer before the search moves on.',
                min: 5,
                max: 120,
                integer: true,
              ),
              const Gap(AppSpacing.md),
              _numberField(
                'maxDriversToTry',
                'Drivers to try',
                'Capped at 10 — the security rules reject a deeper search, so '
                    'a larger number here would only produce refused writes.',
                min: 1,
                max: DispatchDefaults.maxDriversToTry.toDouble(),
                integer: true,
              ),

              const Gap(AppSpacing.xxl),
              Text('Fare table', style: context.text.titleMedium),
              const Gap(AppSpacing.md),
              _numberField('baseFare', 'Flag-down fare (₱)',
                  'Covers everything up to the base distance.',
                  min: 0, max: 500),
              const Gap(AppSpacing.md),
              _numberField('baseDistanceKm', 'Base distance (km)',
                  'Distance included in the flag-down.',
                  min: 0, max: 20),
              const Gap(AppSpacing.md),
              _numberField('farePerKm', 'Per succeeding km (₱)',
                  'Charged per started kilometre beyond the base.',
                  min: 0, max: 500),
              const Gap(AppSpacing.md),
              _numberField('minimumFare', 'Minimum fare (₱)',
                  'No quote falls below this.',
                  min: 0, max: 500),
              const Gap(AppSpacing.md),
              _numberField(
                'discountRate',
                'Statutory discount (0–1)',
                '0.20 is the legal rate for seniors (RA 9994) and PWDs '
                    '(RA 10754). Lowering it below 0.20 is unlawful.',
                min: 0,
                max: 1,
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
                    : const Text('Save settings'),
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
          title: const Text('Stop new bookings?'),
          content: const Text(
            'Commuters will not be able to book until you turn this back on.\n\n'
            'Rides already in progress finish normally — nobody sitting in a '
            'tricycle is stranded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Stop bookings'),
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
              ? 'Bookings resumed.'
              : 'Bookings stopped. Rides in progress will finish.',
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
                    accepting ? 'Accepting bookings' : 'Bookings stopped',
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
                  ? 'Turn this off to halt the pilot. It takes effect on every '
                    'phone within seconds, and needs no app update.'
                  : 'Commuters cannot book. Rides already in progress finish '
                    'normally.',
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
