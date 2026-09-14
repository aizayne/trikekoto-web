import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_theme.dart';

/// The installed version and build number, or null where the platform cannot
/// say (widget tests, some web hosts).
///
/// Errors are swallowed on purpose. Riverpod 3 retries a failing provider on a
/// timer, so letting the plugin's MissingPluginException escape in a widget
/// test would leave timers pending and fail tests that never asked about the
/// version.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
});

/// "TrikeKoTo 1.0.1 (2)", small, at the foot of a screen.
///
/// Exists because every APK used to report version 1.0.0 with no build
/// number anywhere, so "did the update install?" could only be answered by
/// inventing a test that made the new build behave differently. Now it can be
/// read off the screen.
class BuildStamp extends ConsumerWidget {
  const BuildStamp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    if (version == null) return const SizedBox.shrink();
    return Text(
      'TrikeKoTo $version',
      textAlign: TextAlign.center,
      style: context.text.labelSmall
          ?.copyWith(color: context.scheme.onSurfaceVariant),
    );
  }
}
