import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'credit_repository_test.dart' show CreditAuth;
import 'owner_link_test.dart' show LinkAuth;

void main() {
  Future<void> open(
    WidgetTester tester,
    CreditAuth auth,
    MemorySecureStorage storage,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(
            CloudLedgerRepository(auth, OpaqueId.fromJson('owner'), storage),
          ),
          ownerLinkRepositoryProvider.overrideWithValue(
            CloudOwnerLinkRepository(
              LinkAuth(),
              OpaqueId.fromJson('owner'),
              MemorySecureStorage(),
            ),
          ),
        ],
        child: MaterialApp(
          home: CreditPage(
            shopId: OpaqueId.fromJson('shop'),
            linkId: OpaqueId.fromJson('link'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('credit review changes no balance and confirm posts once', (
    tester,
  ) async {
    final auth = CreditAuth()..loseResponse = false,
        storage = MemorySecureStorage();
    await open(tester, auth, storage);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '500',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer owes you'), findsWidgets);
    expect(auth.requests, isEmpty);
    expect(storage.values, isEmpty);
    await tester.tap(find.text('Confirm credit'));
    await tester.pumpAndSettle();
    expect(find.text('Credit acknowledged by server'), findsOneWidget);
    expect(auth.requests.length, 1);
    expect(find.text('Confirm credit'), findsNothing);
  });
  testWidgets('lost response shows uncertainty and retries original request', (
    tester,
  ) async {
    final auth = CreditAuth(), storage = MemorySecureStorage();
    await open(tester, auth, storage);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '500',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm credit'));
    await tester.pumpAndSettle();
    expect(find.text('Credit acknowledged by server'), findsNothing);
    expect(find.textContaining('not confirmed'), findsOneWidget);
    auth.loseResponse = false;
    await tester.tap(find.text('Check same credit'));
    await tester.pumpAndSettle();
    expect(auth.requests[0], auth.requests[1]);
    expect(find.text('Credit acknowledged by server'), findsOneWidget);
  });
  testWidgets('duplicate taps while a credit is in flight create one command', (
    tester,
  ) async {
    final done = Completer<void>();
    final auth = CreditAuth()
      ..loseResponse = false
      ..wait = done.future;
    await open(tester, auth, MemorySecureStorage());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '500',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm credit'));
    await tester.pumpAndSettle();
    expect(auth.requests.length, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Checking credit…'),
          )
          .onPressed,
      isNull,
    );
    done.complete();
    await tester.pumpAndSettle();
    expect(auth.requests.length, 1);
    expect(find.text('Credit acknowledged by server'), findsOneWidget);
  });
  testWidgets(
    'opening a saved credit after restart requires checking the same command',
    (tester) async {
      final auth = CreditAuth()..loseResponse = false;
      final storage = MemorySecureStorage();
      final repo = CloudLedgerRepository(
        auth,
        OpaqueId.fromJson('owner'),
        storage,
      );
      final saved = await repo.begin(
        OpaqueId.fromJson('shop'),
        OpaqueId.fromJson('link'),
        'Customer',
        50000,
        null,
        null,
      );
      await open(tester, auth, storage);
      expect(find.text('Check same credit'), findsOneWidget);
      expect(find.text('Review credit'), findsNothing);
      expect(auth.requests, isEmpty);
      await tester.tap(find.text('Check same credit'));
      await tester.pumpAndSettle();
      expect(auth.requests.single, saved.body);
      expect(find.text('Credit acknowledged by server'), findsOneWidget);
    },
  );
  testWidgets('invalid amount cannot reach review or create a saved credit', (
    tester,
  ) async {
    final auth = CreditAuth(), storage = MemorySecureStorage();
    await open(tester, auth, storage);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '0',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm credit'), findsNothing);
    expect(auth.requests, isEmpty);
    expect(storage.values, isEmpty);
  });
  testWidgets('due date opens a calendar and displays DD-MM-YYYY', (
    tester,
  ) async {
    final auth = CreditAuth()..loseResponse = false;
    await open(tester, auth, MemorySecureStorage());
    await tester.tap(find.widgetWithText(TextFormField, 'Due date (optional)'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final text = tester
        .widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Due date (optional)'),
        )
        .controller!
        .text;
    expect(text, matches(RegExp(r'^\d{2}-\d{2}-\d{4}$')));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '500',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    expect(find.text('Due date: $text'), findsOneWidget);
    await tester.tap(find.text('Confirm credit'));
    await tester.pumpAndSettle();
    expect(
      auth.requests.single['dueDate'],
      '${text.substring(6)}-${text.substring(3, 5)}-${text.substring(0, 2)}',
    );
  });
}
