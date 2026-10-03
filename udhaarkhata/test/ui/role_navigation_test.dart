import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

import '../history_ui_test.dart' show HistoryAuth;

void main() {
  testWidgets('owner tabs and task Back preserve origin and role guard', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          HistoryAuth(AccountRole.owner),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MainApp()),
    );
    await tester.pumpAndSettle();
    final router = container.read(routerProvider);
    router.go('/owner?tab=customers');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    router.push('/recovery');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    router.go('/customer?tab=more');
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
