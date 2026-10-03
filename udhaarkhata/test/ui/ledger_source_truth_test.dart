import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/ledger/history_page.dart';

import '../history_ui_test.dart' show HistoryAuth;

void main() {
  testWidgets(
    'compact history disclosure retains sequence and immutable details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              HistoryAuth(AccountRole.owner),
            ),
          ],
          child: MaterialApp(
            theme: clearCounterTheme(),
            home: const HistoryPage(
              shopId: 'shop',
              linkId: 'link',
              confirmedOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsNothing);
      expect(find.text('Details'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Details').first);
      await tester.tap(find.text('Details').first);
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);
      expect(find.textContaining('Recorded'), findsWidgets);
      expect(find.textContaining('₹500.00'), findsWidgets);
    },
  );
}
