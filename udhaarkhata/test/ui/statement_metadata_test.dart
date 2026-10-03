import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app_strings.dart';

import '../helpers/ux01_fixtures.dart';

void main() {
  testWidgets(
    'statement identifies shop separately from customer nickname and dates its balance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: ux01FixtureSurface('statement-preview', const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare preview'));
      await tester.pumpAndSettle();
      expect(find.text('Shop: Store'), findsOneWidget);
      expect(
        find.textContaining('Server snapshot: 03-10-2026 00:00'),
        findsOneWidget,
      );
      expect(find.textContaining('Nickname in shop: Store'), findsNothing);
    },
  );
}
