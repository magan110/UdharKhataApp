import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';

void main() {
  test('English/Hindi ARB resources and delegate have identical keys and placeholders', () {
    final english = jsonDecode(
      File('l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hindi = jsonDecode(
      File('l10n/app_hi.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(hindi.keys.toSet(), english.keys.toSet());
    for (final key in english.keys.where((k) => !k.startsWith('@'))) {
      expect(hindi[key], isNotEmpty, reason: key);
      expect(AppStrings('en').text(key), english[key], reason: key);
      expect(AppStrings('hi').text(key), hindi[key], reason: key);
      final placeholders = RegExp(r'\{[^}]+\}');
      expect(
        placeholders.allMatches(hindi[key] as String).map((m) => m[0]).toSet(),
        placeholders
            .allMatches(english[key] as String)
            .map((m) => m[0])
            .toSet(),
        reason: key,
      );
    }
  });
  test('Every static translate call in critical application pages has both translations', () {
    final english = jsonDecode(
      File('l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final translated = english.values.toSet();
    final missing = <String>{};
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.endsWith('app_strings.dart'),
            )) {
      for (final match in RegExp(
        r"translate\('([^'\n\$]+)'\)",
      ).allMatches(file.readAsStringSync())) {
        if (!translated.contains(match[1])) {
          missing.add(match[1]!);
        }
      }
    }
    expect(missing, isEmpty);
  });
}
