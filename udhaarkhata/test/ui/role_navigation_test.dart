import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';

import '../history_ui_test.dart' show HistoryAuth;
import '../settings/settings_ui_test.dart' show TestPrivacyAuth;

class RecoveryAuth extends TestPrivacyAuth {
  RecoveryAuth() : super(AccountRole.owner);
  int pendingReads = 0;
  @override
  Future<int> pendingCount() async {
    pendingReads++;
    return 2;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final state in ['no shop', 'loading', 'error']) {
    testWidgets('owner More allows safe sign-out with shop $state', (
      tester,
    ) async {
      final auth = RecoveryAuth();
      final shop = Completer<Shop?>();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          currentShopProvider.overrideWith((ref) => shop.future),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MainApp()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (state == 'no shop') shop.complete(null);
      if (state == 'error') {
        shop.completeError(
          const AppFailure(
            'NETWORK_ERROR',
            'api.networkError',
            retryable: true,
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
      container.read(routerProvider).go('/owner?tab=more');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Language'), findsOneWidget);
      final signOut = find.text('Sign out');
      expect(signOut, findsOneWidget);
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Sign out?'), findsOneWidget);
      expect(
        find.textContaining('2 pending entries will stay on this phone'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(sessionProvider).asData?.value?.id.value,
        auth.account.id.value,
      );
      expect(auth.pendingReads, 1);
      expect(auth.posts, isEmpty);
    });
  }
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
