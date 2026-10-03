import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

import '../settings/settings_ui_test.dart' show TestPrivacyAuth;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'More embeds settings without nested Scaffold and cancelled request makes no write',
    (tester) async {
      final auth = TestPrivacyAuth(AccountRole.customer);
      final c = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const MainApp()),
      );
      await tester.pumpAndSettle();
      c.read(routerProvider).go('/customer?tab=more');
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.ensureVisible(find.text('Request account deletion'));
      await tester.tap(find.text('Request account deletion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.posts, isEmpty);
      expect(
        find.textContaining('does not perform destructive deletion'),
        findsOneWidget,
      );
    },
  );
}
