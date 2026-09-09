import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';

/// Tests for the light/dark setting.
///
/// The default matters more than the toggle: white-and-orange is the product's
/// identity, and it must not depend on how the viewer's handset happens to be
/// configured. The persistence matters because a setting that forgets is worse
/// than no setting — the driver who turned dark on at 2am should not have to
/// do it again the next night.

Future<ProviderContainer> _container([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  _noStoreTests();

  group('default', () {
    test('a fresh install starts light, not on the system setting', () async {
      final c = await _container();
      // Not ThemeMode.system: a panel reviewing screenshots, a first-time
      // driver and a commuter should all see the same app.
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('an unrecognised stored value falls back to light', () async {
      final c = await _container({'themeMode': 'sepia'});
      expect(c.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('persistence', () {
    test('a stored choice is applied on the next start', () async {
      final c = await _container({'themeMode': 'dark'});
      expect(c.read(themeModeProvider), ThemeMode.dark);
    });

    test('system is honoured if something set it', () async {
      final c = await _container({'themeMode': 'system'});
      expect(c.read(themeModeProvider), ThemeMode.system);
    });

    test('toggling writes the choice through', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);

      await c.read(themeModeProvider.notifier).toggle();

      expect(c.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('themeMode'), 'dark');
    });
  });

  group('toggle', () {
    test('flips light to dark and back', () async {
      final c = await _container();
      final notifier = c.read(themeModeProvider.notifier);

      await notifier.toggle();
      expect(c.read(themeModeProvider), ThemeMode.dark);

      await notifier.toggle();
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('never lands on system, which the button cannot represent', () async {
      // A two-state control that silently has three states is one nobody can
      // predict — the second tap would appear to do nothing.
      final c = await _container({'themeMode': 'system'});
      await c.read(themeModeProvider.notifier).toggle();
      expect(c.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('what the button shows', () {
    testWidgets('offers dark while light is showing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(appBar: null, body: ThemeToggleButton()),
        ),
      ));

      // The tooltip names where you are going, not where you are.
      expect(find.byTooltip('Switch to dark'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    });

    testWidgets('offers light once dark is showing', (tester) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
      ));

      expect(find.byTooltip('Switch to light'), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    });

    testWidgets('tapping it changes the icon', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
      ));

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    });
  });
}

// Regression: an unavailable preference store must not break the app.
// An earlier version let this throw out of main() before runApp, which
// rendered a blank page with nothing on screen to explain it.
void _noStoreTests() {
  group('no preference store', () {
    ProviderContainer bare() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('falls back to light rather than failing', () {
      expect(bare().read(themeModeProvider), ThemeMode.light);
    });

    test('the toggle still works for the session', () async {
      final c = bare();
      await c.read(themeModeProvider.notifier).toggle();
      expect(c.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
