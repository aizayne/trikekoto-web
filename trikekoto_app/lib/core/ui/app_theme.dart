import 'package:flutter/material.dart';

/// Design tokens and themes for TrikeKoTo.
///
/// The palette is taken from the launcher icon — brand amber on navy — so the
/// app and the tile a driver taps belong to the same product. It replaces an
/// earlier route-blue direction, which read as a different app entirely once
/// the icon was set.
///
/// The Swiss-minimal structure from the `ui-ux-pro-max` design-system query
/// is unchanged: generous whitespace, one accent, tokens rather than literals.
/// What changed is the hue, and every contrast pairing was re-measured rather
/// than assumed.
///
/// **The rule that shapes everything below: amber is a fill, not an ink.**
/// It measures 2.03:1 on white, so it can never carry text on a light
/// surface. On light it is a button colour with navy ink; on navy it clears
/// 8.59:1 and becomes the text colour. Text and links on light surfaces use
/// [AppColors.action], a darkened orange at 5.02:1.
///
/// Two deviations from the skill's output, both deliberate:
///
///  * **Typography.** The recommended pairing is Poppins/Open Sans. Open Sans
///    now ships only as a variable font, and Flutter synthesises rather than
///    selects weights from it, which looks poor on low-end screens. Poppins
///    carries display and headings; body text uses the platform face.
///  * **The landing-page pattern** it returned (hero, product video, CTA) is
///    for a marketing site. This is a working app, so it is ignored.
class AppColors {
  const AppColors._();

  // ── Brand amber, taken from the launcher icon ───────────────
  //
  // Amber is a *fill*, not an ink. Measured against white it reaches only
  // 2.03:1, far below the 4.5:1 needed for text, so it never carries a
  // label on a light surface. On the brand navy it reaches 8.59:1, which is
  // why it becomes the text colour in dark mode and the button colour in
  // light mode — with navy ink on top rather than white.
  static const brand = Color(0xFFF5A623);
  static const brandPressed = Color(0xFFDB9016);

  /// Ink placed on top of [brand]. Navy, not white: 8.59:1 against 2.03:1.
  static const onAccent = Color(0xFF101A2C);

  /// The darkened orange that carries text and links on light surfaces —
  /// 5.02:1 on white. Amber itself cannot do this job.
  static const action = Color(0xFFB45309);

  // Kept so map pins and other fills keep one name for the brand colour.
  static const accent = brand;
  static const accentPressed = brandPressed;

  // ── Navy ground, from the icon ──────────────────────────────
  static const navy900 = Color(0xFF0B1220);
  static const navy850 = Color(0xFF101A2C);
  static const navy800 = Color(0xFF18243A);
  static const navy700 = Color(0xFF243349);

  // ── Warm neutrals ───────────────────────────────────────────
  // Stone rather than slate: a neutral biased toward the accent's hue reads
  // as chosen, where a blue-grey beside an amber accent reads as leftover
  // from the previous palette.
  static const stone500 = Color(0xFF78716C);
  static const stone400 = Color(0xFFA8A29E);
  static const stone300 = Color(0xFFD6D3D1);
  static const stone200 = Color(0xFFE7E5E4);
  static const stone100 = Color(0xFFF5F5F4);
  static const stone50 = Color(0xFFFAF8F5);

  // ── Semantic state ──────────────────────────────────────────
  // None of these may be amber. The brand now owns that hue, and a status
  // that looks like the primary action is a status nobody reads correctly.
  // "Pending" is informational rather than a warning, so it takes blue —
  // which also keeps it clearly distinct from the accent.
  static const success = Color(0xFF15803D);
  static const successDark = Color(0xFF4ADE80);
  static const info = Color(0xFF1D4ED8);
  static const infoDark = Color(0xFF7FB9E5);
  static const danger = Color(0xFFB91C1C);
  static const dangerDark = Color(0xFFF87171);
}

/// Spacing, sizing, and motion tokens.
///
/// A 4dp base grid. Using tokens rather than literals is what keeps rhythm
/// consistent once several screens exist.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Android's minimum touch target. Anything tappable is at least this tall,
  /// including when its icon is smaller — drivers tap while the trike is
  /// moving, so undersized targets are a safety problem, not just a polish one.
  static const minTouchTarget = 48.0;

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;

  static const iconSm = 18.0;
  static const iconMd = 24.0;
  static const iconLg = 32.0;
}

/// Motion tokens, chosen per distance rather than one duration reused
/// everywhere.
class AppMotion {
  const AppMotion._();

  /// State changes in place — a switch, a chip, a press.
  static const fast = Duration(milliseconds: 150);

  /// Elements entering or leaving a surface.
  static const medium = Duration(milliseconds: 250);

  /// Full-surface transitions.
  static const slow = Duration(milliseconds: 350);

  static const easing = Curves.easeOutCubic;
}

/// Semantic colours that Material's [ColorScheme] has no slot for.
///
/// Registered as a [ThemeExtension] so a screen reads
/// `Theme.of(context).extension<AppSemanticColors>()` instead of hardcoding a
/// hex per screen — the driver status banner previously did exactly that,
/// which meant it did not adapt to dark mode at all.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;

  static const light = AppSemanticColors(
    success: AppColors.success,
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: AppColors.info,
    warningContainer: Color(0xFFDBEAFE),
    danger: AppColors.danger,
    dangerContainer: Color(0xFFFEE2E2),
  );

  static const dark = AppSemanticColors(
    success: AppColors.successDark,
    successContainer: Color(0xFF14352A),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: AppColors.infoDark,
    warningContainer: Color(0xFF13253C),
    danger: AppColors.dangerDark,
    dangerContainer: Color(0xFF3B1A1A),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
  }) =>
      AppSemanticColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        warning: warning ?? this.warning,
        warningContainer: warningContainer ?? this.warningContainer,
        danger: danger ?? this.danger,
        dangerContainer: dangerContainer ?? this.dangerContainer,
      );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
    );
  }
}

/// Convenience access to the semantic palette.
extension AppThemeContext on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;

  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(_lightScheme, AppSemanticColors.light);
  static ThemeData get dark => _build(_darkScheme, AppSemanticColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary is the navy from the icon, so headings and app bars belong to
    // the same identity as the launcher tile.
    primary: AppColors.navy850,
    onPrimary: Colors.white,
    primaryContainer: AppColors.stone200,
    onPrimaryContainer: AppColors.navy900,
    // Secondary carries the darkened orange, because Material uses this slot
    // for text and icons where amber would fail contrast.
    secondary: AppColors.action,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFDECD2),
    onSecondaryContainer: Color(0xFF7C3D06),
    tertiary: AppColors.stone500,
    onTertiary: Colors.white,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Colors.white,
    onSurface: Color(0xFF1C1917),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColors.stone50,
    surfaceContainer: AppColors.stone100,
    surfaceContainerHigh: AppColors.stone200,
    // 7.2:1 on the cream ground — secondary text stays readable rather than
    // becoming the grey-on-grey the skill's checklist warns about.
    onSurfaceVariant: Color(0xFF57534E),
    outline: AppColors.stone500,
    outlineVariant: AppColors.stone300,
    inverseSurface: AppColors.navy900,
    onInverseSurface: Colors.white,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.stone200,
    onPrimary: AppColors.navy900,
    primaryContainer: AppColors.navy800,
    onPrimaryContainer: Colors.white,
    // On navy, amber itself clears 8.59:1 — so in dark mode the brand colour
    // can carry text, which it cannot do on white.
    secondary: AppColors.brand,
    onSecondary: AppColors.navy900,
    secondaryContainer: Color(0xFF3A2A10),
    onSecondaryContainer: Color(0xFFFBD9A0),
    tertiary: AppColors.stone400,
    onTertiary: AppColors.navy900,
    error: AppColors.dangerDark,
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: AppColors.navy850,
    onSurface: Color(0xFFF5F5F4),
    surfaceContainerLowest: AppColors.navy900,
    surfaceContainerLow: AppColors.navy800,
    surfaceContainer: AppColors.navy800,
    surfaceContainerHigh: AppColors.navy700,
    // Stone-400 on navy clears 6.9:1.
    onSurfaceVariant: AppColors.stone400,
    outline: Color(0xFF6B7280),
    outlineVariant: AppColors.navy700,
    inverseSurface: AppColors.stone100,
    onInverseSurface: AppColors.navy900,
  );

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    // Poppins for anything that carries hierarchy; the platform face for
    // running text.
    final text = base.textTheme.copyWith(
      displaySmall: _display(38, FontWeight.w700, scheme),
      headlineMedium: _display(28, FontWeight.w700, scheme),
      headlineSmall: _display(24, FontWeight.w600, scheme),
      titleLarge: _display(20, FontWeight.w600, scheme),
      titleMedium: _display(17, FontWeight.w600, scheme),
      titleSmall: _display(15, FontWeight.w600, scheme),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurface),
      // 13px floor: nothing informative drops below it.
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: _display(15, FontWeight.w600, scheme),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor:
          isDark ? scheme.surfaceContainerLowest : AppColors.stone50,
      extensions: [semantic],

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? scheme.surface : Colors.white,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: _display(20, FontWeight.w600, scheme),
      ),

      // The brand amber is reserved for the primary action on a screen, and
      // always carries navy ink — white on amber measures 2.03:1.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget + 4),
          textStyle: _display(15, FontWeight.w600, scheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: _display(15, FontWeight.w600, scheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // scheme.secondary resolves to the darkened orange on light and to
          // brand amber on dark — the only two values that pass 4.5:1 on
          // their respective grounds.
          foregroundColor: scheme.secondary,
          minimumSize: const Size(AppSpacing.minTouchTarget,
              AppSpacing.minTouchTarget),
          textStyle: _display(15, FontWeight.w600, scheme),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget,
              AppSpacing.minTouchTarget),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        // Labels stay visible above the field rather than living in the
        // placeholder, which disappears the moment someone starts typing.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          // Borders are defined for both themes; a divider that exists only
          // in light mode makes the dark layout read as flat.
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.onAccent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
      ),

      chipTheme: ChipThemeData(
        labelStyle: text.bodySmall,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),

      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: scheme.secondary),
    );
  }

  static TextStyle _display(double size, FontWeight weight, ColorScheme s) =>
      TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: weight,
        color: s.onSurface,
        height: 1.25,
        letterSpacing: size >= 24 ? -0.5 : -0.1,
      );
}

/// Fixed-size gap. Prefer a token: `Gap(AppSpacing.lg)`.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// A blank region with a line of explanation and, where there is one, the
/// action that fills it. An empty screen with nothing on it reads as broken.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          children: [
            Icon(icon, size: AppSpacing.iconLg, color: scheme.onSurfaceVariant),
            const Gap(AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (body != null) ...[
              const Gap(AppSpacing.xs),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (action != null) ...[
              const Gap(AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.error : null,
      ),
    );
}

/// Firestore permission failures are the most common error in this app while
/// rules are being tuned, and `[cloud_firestore/permission-denied] ...` tells
/// a driver nothing. Each message says what happened and what to do next.
String describeError(Object error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'The server refused that action. You may not be approved yet.';
  }
  if (text.contains('unavailable')) {
    return 'Cannot reach the server. Check your connection and try again.';
  }
  if (text.contains('email-already-in-use')) {
    return 'That email is already registered. Sign in instead.';
  }
  if (text.contains('wrong-password') || text.contains('invalid-credential')) {
    return 'Wrong email or password.';
  }
  if (text.contains('weak-password')) {
    return 'Use a password of at least 6 characters.';
  }
  if (text.contains('network-request-failed')) {
    return 'No internet connection.';
  }
  return text.replaceAll(RegExp(r'\[.*?\]\s*'), '');
}
