import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two locale files have to stay in step.
///
/// Nothing in the build enforces this. `flutter gen-l10n` warns about an
/// untranslated key and then generates anyway, falling back to the template —
/// so an English-speaking user quietly gets a Filipino string and nobody sees
/// a red line. This test is the thing that makes it fail loudly instead.
///
/// It reads the .arb files as data rather than going through the generated
/// class, because the generated class cannot represent the failure: a key
/// missing from English simply is not there to assert on.
void main() {
  Map<String, dynamic> load(String name) => jsonDecode(
        File('lib/l10n/$name').readAsStringSync(),
      ) as Map<String, dynamic>;

  final fil = load('app_fil.arb');
  final en = load('app_en.arb');

  Set<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('every Filipino string has an English one', () {
    final missing = keysOf(fil).difference(keysOf(en));
    expect(missing, isEmpty,
        reason: 'These keys would silently render in Filipino for someone '
            'who chose English: ${missing.join(', ')}');
  });

  test('English carries no key Filipino lacks', () {
    // The other direction is not merely untidy: Filipino is the template, so
    // a key only English has was never added to the source of truth and will
    // not exist on the generated class at all.
    final extra = keysOf(en).difference(keysOf(fil));
    expect(extra, isEmpty, reason: 'Orphaned in English: ${extra.join(', ')}');
  });

  test('placeholders match between the two', () {
    // A translation that drops a placeholder compiles and then renders a
    // sentence with a hole in it — "sent to ." — which reads as a bug to the
    // user and as nothing at all to the compiler.
    final holes = RegExp(r'\{(\w+)\}');
    final mismatched = <String>[];

    for (final key in keysOf(fil)) {
      final f = holes.allMatches(fil[key] as String).map((m) => m[1]).toSet();
      final e = holes.allMatches(en[key] as String).map((m) => m[1]).toSet();
      if (f.length != e.length || !f.containsAll(e)) {
        mismatched.add('$key (fil: $f, en: $e)');
      }
    }

    expect(mismatched, isEmpty,
        reason: 'Placeholder sets differ:\n${mismatched.join('\n')}');
  });

  test('no string is left empty', () {
    // An empty translation is worse than an untranslated one: the screen
    // renders a blank where a label should be, and the layout usually still
    // looks deliberate.
    for (final arb in [fil, en]) {
      for (final key in keysOf(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty,
            reason: '$key is empty in ${arb['@@locale']}');
      }
    }
  });
}
