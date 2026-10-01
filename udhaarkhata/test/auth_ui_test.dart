import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

class InteractiveAuth extends AuthRepository {
  bool cancelled = false;
  @override
  bool get canSignIn => true;
  @override
  Future<Account?> restoreSession() async => null;
  @override
  Future<Account> signIn(AccountRole role) async {
    if (cancelled) {
      throw const AppFailure('SIGN_IN_CANCELLED', 'auth.cancelled');
    }
    return Account(
      id: OpaqueId.fromJson('synthetic'),
      role: role,
      displayName: 'Synthetic',
      createdAtMs: 1,
    );
  }

  @override
  Future<int> pendingCount() async => 2;
  @override
  Future<({int pendingCount, bool remoteRevoked})> signOut() async =>
      (pendingCount: 2, remoteRevoked: true);
}

void main() {
  testWidgets(
    'Google action routes the confirmed role and signout warns about pending entries',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(InteractiveAuth()),
          ],
          child: const MainApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer'));
      await tester.pump();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Your shops'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 pending entries'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );
  testWidgets(
    'cancelled Google sign-in offers a safe return to role selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              InteractiveAuth()..cancelled = true,
            ),
          ],
          child: const MainApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sign-in was cancelled. You can try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );
}
