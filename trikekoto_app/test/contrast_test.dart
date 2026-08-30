import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';

/// WCAG contrast checks on the palette.
///
/// These exist because the amber retheme is exactly the kind of change that
/// looks right on a designer's monitor and fails for a driver holding a cheap
/// phone in daylight. Amber measures 2.03:1 on white — a value nobody would
/// guess by eye, because the colour *feels* vivid.
///
/// Anyone changing a colour token will trip these before it reaches a device.

/// Relative luminance, per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 4.5:1 — normal body text.
Matcher passesBodyText() => greaterThanOrEqualTo(4.5);

/// 3:1 — large text, icons, and control boundaries.
Matcher passesNonText() => greaterThanOrEqualTo(3.0);

void main() {
  final light = AppTheme.light.colorScheme;
  final dark = AppTheme.dark.colorScheme;

  group('the rule the whole palette rests on', () {
    test('amber cannot carry text on white, and is not asked to', () {
      // Documents *why* AppColors.action exists. If this ever passes, amber
      // has been changed and the separate action colour may be redundant.
      expect(contrast(AppColors.brand, Colors.white), lessThan(4.5));
    });

    test('navy ink on amber is legible', () {
      expect(contrast(AppColors.onAccent, AppColors.brand), passesBodyText());
    });

    test('the action orange carries text on light surfaces', () {
      expect(contrast(AppColors.action, Colors.white), passesBodyText());
      expect(contrast(AppColors.action, AppColors.stone50), passesBodyText());
    });

    test('amber carries text on the navy ground', () {
      expect(contrast(AppColors.brand, AppColors.navy850), passesBodyText());
    });
  });

  group('light theme', () {
    test('body text on every surface', () {
      expect(contrast(light.onSurface, light.surface), passesBodyText());
      expect(contrast(light.onSurface, light.surfaceContainerLow),
          passesBodyText());
      expect(contrast(light.onSurface, light.surfaceContainer),
          passesBodyText());
    });

    test('secondary text is not grey-on-grey', () {
      expect(contrast(light.onSurfaceVariant, light.surface), passesBodyText());
      expect(contrast(light.onSurfaceVariant, light.surfaceContainerLow),
          passesBodyText());
    });

    test('primary and error text', () {
      expect(contrast(light.onPrimary, light.primary), passesBodyText());
      expect(contrast(light.onError, light.error), passesBodyText());
      expect(contrast(light.onSecondary, light.secondary), passesBodyText());
    });

    test('container text', () {
      expect(contrast(light.onSecondaryContainer, light.secondaryContainer),
          passesBodyText());
      expect(contrast(light.onErrorContainer, light.errorContainer),
          passesBodyText());
    });

    test('borders are visible against their surface', () {
      expect(contrast(light.outline, light.surface), passesNonText());
    });
  });

  group('dark theme', () {
    test('body text on every surface', () {
      expect(contrast(dark.onSurface, dark.surface), passesBodyText());
      expect(contrast(dark.onSurface, dark.surfaceContainerLow),
          passesBodyText());
      expect(contrast(dark.onSurface, dark.surfaceContainerHigh),
          passesBodyText());
    });

    test('secondary text stays above the text threshold, not just 3:1', () {
      // The common dark-mode failure: muted grey that would pass for large
      // text but is used for body copy.
      expect(contrast(dark.onSurfaceVariant, dark.surface), passesBodyText());
      expect(contrast(dark.onSurfaceVariant, dark.surfaceContainerLow),
          passesBodyText());
    });

    test('primary, secondary and error text', () {
      expect(contrast(dark.onPrimary, dark.primary), passesBodyText());
      expect(contrast(dark.onSecondary, dark.secondary), passesBodyText());
      expect(contrast(dark.onError, dark.error), passesBodyText());
    });

    test('container text', () {
      expect(contrast(dark.onSecondaryContainer, dark.secondaryContainer),
          passesBodyText());
      expect(contrast(dark.onErrorContainer, dark.errorContainer),
          passesBodyText());
    });

    test('borders do not disappear — the dark-mode divider trap', () {
      expect(contrast(dark.outline, dark.surface), passesNonText());
    });
  });

  group('semantic colours', () {
    test('each status is legible on its own container, both themes', () {
      for (final (name, semantic, surface) in [
        ('light', AppSemanticColors.light, Colors.white),
        ('dark', AppSemanticColors.dark, AppColors.navy850),
      ]) {
        expect(contrast(semantic.success, semantic.successContainer),
            passesNonText(),
            reason: 'success on its container ($name)');
        expect(contrast(semantic.warning, semantic.warningContainer),
            passesNonText(),
            reason: 'pending on its container ($name)');
        expect(contrast(semantic.danger, semantic.dangerContainer),
            passesNonText(),
            reason: 'danger on its container ($name)');

        // Status icons sit directly on the card in some places too.
        expect(contrast(semantic.danger, surface), passesNonText(),
            reason: 'danger on the surface ($name)');
      }
    });

    test('no status colour is the brand amber', () {
      // A status that looks like the primary action is a status nobody reads
      // correctly. This is the guard on that rule.
      for (final semantic in [AppSemanticColors.light, AppSemanticColors.dark]) {
        for (final c in [semantic.success, semantic.warning, semantic.danger]) {
          expect(c, isNot(AppColors.brand));
          expect(c, isNot(AppColors.action));
        }
      }
    });
  });
}
