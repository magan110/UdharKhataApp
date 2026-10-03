import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/ux01_fixtures.dart';

void main() {
  testWidgets(
    'workspace separates saved and synced balances with complete and partial dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ux01FixtureSurface(
            'owner-workspace-partial',
            const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹650.00'), findsOneWidget);
      expect(find.text('Synced balance: ₹500.00'), findsOneWidget);
      expect(
        find.textContaining('Server snapshot: 03-10-2026 00:00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Partial refresh: 03-10-2026 00:01'),
        findsOneWidget,
      );
      expect(find.textContaining('₹20,000.00'), findsNothing);
    },
  );
}
