import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set in `main()` once the store has loaded, so the theme can be read
/// synchronously below.
///
/// Reading preferences asynchronously would mean the app paints its default
/// theme first and corrects itself a frame later — a white flash on every
/// cold start for anyone who chose dark, which is exactly the person most
/// bothered by it.
///
/// **Nullable on purpose.** The store is unavailable on some platforms, and
/// an earlier version of this let that failure escape `main()` before
/// `runApp` — which rendered a blank page, exactly the way the Crashlytics
/// call did. Remembering a theme is a convenience; it must never be able to
/// stop the app from starting.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

const _key = 'themeMode';

/// The app's light/dark setting.
///
/// **Defaults to light.** The white-and-orange scheme is the product's
/// identity, and it is what a first-time driver, a commuter, and a panel
/// reviewing screenshots should all see without configuring anything.
///
/// Dark stays available rather than being deleted, because a driver reading
/// this at 2am on a night shift is holding a torch otherwise. It is a choice
/// they make, not one their phone makes for them.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider)?.getString(_key);
    return switch (stored) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> set(ThemeMode mode) async {
    // Applied first, saved second. With no store the toggle still works for
    // this session; it simply forgets on restart.
    state = mode;
    await ref.read(sharedPreferencesProvider)?.setString(_key, mode.name);
  }

  /// What the button does: flip between the two the user can actually see.
  /// `system` is honoured if something else sets it, but is not part of the
  /// cycle — a two-state control that silently has three states is a control
  /// nobody can predict.
  Future<void> toggle() => set(
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Whether dark is currently being shown, accounting for [ThemeMode.system].
bool isDarkNow(BuildContext context, ThemeMode mode) => switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

/// App-bar control for switching themes.
///
/// Sits beside the sign-out action on every screen that has an app bar. There
/// is no settings screen to put it in, and burying it behind one would be
/// worse: this is a comfort setting, wanted at the moment the screen is too
/// bright rather than remembered later.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final dark = isDarkNow(context, mode);

    return IconButton(
      // Names the destination, not the current state — "Dark mode" on a
      // button that turns dark mode off reads as a label, not an action.
      tooltip: dark ? 'Switch to light' : 'Switch to dark',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
