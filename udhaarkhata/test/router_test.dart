import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';

import 'helpers/fake_auth_repository.dart';

Account syntheticAccount(AccountRole role) => Account(
  id: OpaqueId.fromJson('usr_synthetic'),
  role: role,
  displayName: 'Synthetic',
  createdAtMs: 1790726400000,
);

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        shopRepositoryProvider.overrideWithValue(
          const UnconfiguredShopRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MainApp()),
    );
    return container;
  }

  testWidgets('signed-out deep links cannot enter either role shell', (
    tester,
  ) async {
    final container = await mount(tester, FakeAuthRepository(() async => null));
    await tester.pumpAndSettle();
    for (final path in ['/owner', '/customer']) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Your shop'), findsNothing);
      expect(find.text('Your shops'), findsNothing);
    }
  });

  for (final role in AccountRole.values) {
    testWidgets('$role cannot deep-link into the other role shell', (
      tester,
    ) async {
      final container = await mount(
        tester,
        FakeAuthRepository(() async => syntheticAccount(role)),
      );
      await tester.pumpAndSettle();
      container
          .read(routerProvider)
          .go(role == AccountRole.owner ? '/customer' : '/owner');
      await tester.pumpAndSettle();
      expect(
        find.text(role == AccountRole.owner ? 'Your shop' : 'My QR'),
        role == AccountRole.owner ? findsOneWidget : findsNWidgets(2),
      );
      expect(find.text('Continue with Google'), findsNothing);
    });
  }

  testWidgets(
    'pending session shows a loading state before the welcome screen',
    (tester) async {
      final pending = Completer<Account?>();
      await mount(tester, FakeAuthRepository(() => pending.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets('restore failure offers retry without exposing exception text', (
    tester,
  ) async {
    var attempts = 0;
    await mount(
      tester,
      FakeAuthRepository(() async {
        if (attempts++ == 0) throw StateError('SENSITIVE_SENTINEL');
        return null;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('SENSITIVE_SENTINEL'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('sign-in control is disabled before Google integration', (
    tester,
  ) async {
    await mount(tester, FakeAuthRepository(() async => null));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
