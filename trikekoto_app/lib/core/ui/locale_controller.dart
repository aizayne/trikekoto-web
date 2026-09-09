import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'theme_controller.dart' show sharedPreferencesProvider;

const _key = 'locale';

/// The two languages the app ships in.
///
/// Filipino first, and it is the default: this is built for a TODA chapter in
/// San Marcelino, and the person most likely to struggle with the app is
/// least likely to prefer English. English exists because some drivers and
/// most administrators read it comfortably, and because a panel reviewing
/// this project should be able to read every screen.
///
/// Two, not more. A language list is a promise to keep translating, and a
/// third locale nobody maintains is worse than no third locale — it goes
/// stale silently and shows people a mix of languages, which is the exact
/// problem this feature exists to remove.
enum AppLanguage {
  filipino(Locale('fil'), 'Filipino', 'FIL'),
  english(Locale('en'), 'English', 'EN');

  const AppLanguage(this.locale, this.label, this.short);

  final Locale locale;

  /// Shown in its own language, never translated. Someone looking for English
  /// scans for the word "English", not for "Ingles".
  final String label;

  /// For the toggle, where there is room for two or three characters.
  final String short;

  static AppLanguage fromTag(String? tag) => switch (tag) {
        'en' => AppLanguage.english,
        _ => AppLanguage.filipino,
      };
}

/// The app's language setting.
///
/// Follows [ThemeController] exactly, including the part that matters most:
/// the stored value is read synchronously from a store that may be null. A
/// language that arrives one frame late would repaint every screen, and a
/// preference load that can throw must never be able to stop the app from
/// starting — that mistake has already been made once in this file's sibling
/// and cost a blank page.
///
/// **Deliberately not device-derived.** A handset set to English is not
/// evidence its owner prefers English — cheap Android phones ship that way
/// and most people never change it. Defaulting to the device locale would
/// hand English to exactly the drivers this app is for.
class LocaleController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final stored = ref.watch(sharedPreferencesProvider)?.getString(_key);
    return AppLanguage.fromTag(stored);
  }

  Future<void> set(AppLanguage language) async {
    // Applied first, saved second. With no store the switch still works for
    // this session; it simply forgets on restart.
    state = language;
    await ref.read(sharedPreferencesProvider)?.setString(_key, language.locale.languageCode);
  }

  Future<void> toggle() => set(
        state == AppLanguage.filipino ? AppLanguage.english : AppLanguage.filipino,
      );
}

final localeProvider =
    NotifierProvider<LocaleController, AppLanguage>(LocaleController.new);

/// Flips the language, and says which one it will flip *to*.
///
/// The label shows the other language rather than the current one. A control
/// captioned "FIL" while the screen is already in Filipino tells you nothing
/// and invites a pointless tap; one captioned "EN" tells you what pressing it
/// does. Same reasoning as the theme toggle beside it.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final other = current == AppLanguage.filipino
        ? AppLanguage.english
        : AppLanguage.filipino;

    return TextButton(
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
      // Named in the target language, so the tooltip is readable to whoever
      // is looking for it.
      child: Semantics(
        label: 'Switch to ${other.label}',
        child: Text(other.short),
      ),
    );
  }
}

/// `L.of(context)` at every call site is noise. `context.l` is not.
extension L10nContext on BuildContext {
  L get l => L.of(this);
}
