import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/features/shop/owner_shell.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

import 'helpers/fake_auth_repository.dart';
import 'router_test.dart' show syntheticAccount;

import 'package:udhaarkhata/core/auth/account.dart';

class TestShopRepository implements ShopRepository {
  Shop? shop;
  int creates = 0;
  bool fail = false;
  bool expired = false;
  Completer<Shop>? pending;
  @override
  Future<Shop?> currentShop() async {
    if (expired) throw const AppFailure('AUTH_REQUIRED', 'auth.required');
    return shop;
  }

  @override
  Future<Shop> createShop(String name) async {
    creates++;
    if (fail) throw const AppFailure('NETWORK_ERROR', 'api.networkError');
    return shop = pending == null
        ? Shop(OpaqueId.fromJson('shop'), name.trim())
        : await pending!.future;
  }
}

void main() {
  testWidgets(
    'expired shop access returns to sign-in instead of retrying a dead session',
    (tester) async {
      var restores = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                () async => restores++ == 0
                    ? syntheticAccount(AccountRole.owner)
                    : null,
              ),
            ),
            shopRepositoryProvider.overrideWithValue(
              TestShopRepository()..expired = true,
            ),
          ],
          child: const MainApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );
  testWidgets(
    'setup validates, prevents double submit and opens the acknowledged shop',
    (tester) async {
      final repo = TestShopRepository()..pending = Completer<Shop>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [shopRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: OwnerShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create shop'));
      await tester.pump();
      expect(repo.creates, 0);
      await tester.enterText(find.byType(TextFormField), 'Kiran Store');
      await tester.tap(find.text('Create shop'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Creating shop…'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.creates, 1);
      repo.pending!.complete(Shop(OpaqueId.fromJson('shop'), 'Kiran Store'));
      await tester.pumpAndSettle();
      expect(find.text('Kiran Store'), findsOneWidget);
      expect(find.text('Create shop'), findsNothing);
    },
  );
  testWidgets('failed creation keeps the entered name and allows retry', (
    tester,
  ) async {
    final repo = TestShopRepository()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [shopRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: OwnerShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'My Shop');
    await tester.tap(find.text('Create shop'));
    await tester.pumpAndSettle();
    expect(find.text('My Shop'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Create shop'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('My Shop'), findsOneWidget);
  });
}
