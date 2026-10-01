import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/payment_form.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'payment_repository_test.dart' show PaymentAuth;
import 'owner_link_test.dart' show LinkAuth, linkJson;

void main() {
  final shop = OpaqueId.fromJson('shop'),
      link = OpaqueId.fromJson('link'),
      owner = OpaqueId.fromJson('owner');
  Future<void> open(
    WidgetTester tester,
    PaymentAuth auth,
    MemorySecureStorage storage, {
    LinkAuth? links,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(
            CloudLedgerRepository(auth, owner, storage),
          ),
          ownerLinkRepositoryProvider.overrideWithValue(
            CloudOwnerLinkRepository(
              links ??
                  (LinkAuth()
                    ..response = {
                      ...linkJson,
                      'balancePaise': 50000,
                      'ledgerVersion': 1,
                    }),
              owner,
              MemorySecureStorage(),
            ),
          ),
        ],
        child: MaterialApp(
          home: PaymentPage(shopId: shop, linkId: link),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester, {String amount = '200'}) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount received (₹)'),
      amount,
    );
    await tester.tap(find.text('Review payment'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Cash review has no effect; confirmation records payment once with received wording',
    (tester) async {
      final auth = PaymentAuth()..loseResponse = false,
          storage = MemorySecureStorage();
      await open(tester, auth, storage);
      await review(tester);
      expect(find.text('Cash received: ₹200.00'), findsOneWidget);
      expect(find.textContaining('manually recorded'), findsWidgets);
      expect(auth.requests, isEmpty);
      expect(storage.values, isEmpty);
      await tester.tap(find.text('Confirm payment received'));
      await tester.pumpAndSettle();
      expect(find.text('Payment acknowledged by server'), findsOneWidget);
      expect(find.textContaining('₹300.00'), findsOneWidget);
      expect(auth.requests.single['paymentMethod'], 'cash');
      expect(find.text('Confirm payment received'), findsNothing);
    },
  );
  testWidgets(
    'UPI selection is reviewed and saved; uncertain response retries exact operation',
    (tester) async {
      final auth = PaymentAuth(), storage = MemorySecureStorage();
      await open(tester, auth, storage);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPI').last);
      await tester.pumpAndSettle();
      await review(tester);
      expect(find.text('UPI received: ₹200.00'), findsOneWidget);
      await tester.tap(find.text('Confirm payment received'));
      await tester.pumpAndSettle();
      expect(find.textContaining('may already'), findsOneWidget);
      expect(find.text('Edit amount and method'), findsNothing);
      auth.loseResponse = false;
      await tester.tap(find.text('Check same payment'));
      await tester.pumpAndSettle();
      expect(auth.requests[0], auth.requests[1]);
      expect(auth.requests.last['paymentMethod'], 'upi');
    },
  );
  testWidgets(
    'duplicate taps while payment is in flight create one saved request',
    (tester) async {
      final done = Completer<void>(),
          auth = PaymentAuth()
            ..loseResponse = false
            ..wait = done.future;
      await open(tester, auth, MemorySecureStorage());
      await review(tester);
      await tester.tap(find.text('Confirm payment received'));
      await tester.pumpAndSettle();
      expect(auth.requests.length, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Checking payment…'),
            )
            .onPressed,
        isNull,
      );
      done.complete();
      await tester.pumpAndSettle();
      expect(auth.requests.length, 1);
    },
  );
  testWidgets(
    'saved payment after restart checks original without creating another request',
    (tester) async {
      final auth = PaymentAuth()..loseResponse = false,
          storage = MemorySecureStorage(),
          repo = CloudLedgerRepository(auth, owner, storage);
      final saved = await repo.beginPayment(
        shop,
        link,
        'Customer',
        20000,
        'upi',
      );
      await open(tester, auth, storage);
      expect(find.text('Check same payment'), findsOneWidget);
      expect(find.text('Review payment'), findsNothing);
      expect(auth.requests, isEmpty);
      await tester.tap(find.text('Check same payment'));
      await tester.pumpAndSettle();
      expect(auth.requests.single, saved.body);
    },
  );
  testWidgets(
    'balance rejection shows refreshed balance; explicit correction keeps entered amount until edited',
    (tester) async {
      final auth = PaymentAuth()..reject = true,
          storage = MemorySecureStorage(),
          links = LinkAuth()
            ..response = {
              ...linkJson,
              'balancePaise': 50000,
              'ledgerVersion': 1,
            };
      await open(tester, auth, storage, links: links);
      await review(tester, amount: '400');
      links.response = {...linkJson, 'balancePaise': 10000, 'ledgerVersion': 2};
      await tester.tap(find.text('Confirm payment received'));
      await tester.pumpAndSettle();
      expect(
        find.text('Payment rejected; no payment was recorded.'),
        findsOneWidget,
      );
      expect(find.textContaining('₹100.00'), findsOneWidget);
      await tester.tap(find.text('Edit amount and method'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Amount received (₹)'),
            )
            .controller!
            .text,
        '400.00',
      );
      await review(tester, amount: '50');
      auth.reject = false;
      auth.loseResponse = false;
      await tester.tap(find.text('Confirm payment received'));
      await tester.pumpAndSettle();
      expect(auth.requests.last['amountPaise'], 5000);
      expect(
        auth.requests.first['clientOperationId'],
        isNot(auth.requests.last['clientOperationId']),
      );
      expect(
        storage.values.values.any(
          (text) =>
              text.contains(auth.requests.first['clientOperationId'] as String),
        ),
        true,
      );
    },
  );
  testWidgets('zero amount stays in draft with no payment request', (
    tester,
  ) async {
    final auth = PaymentAuth();
    await open(tester, auth, MemorySecureStorage());
    await review(tester, amount: '0');
    expect(auth.requests, isEmpty);
    expect(find.text('Confirm payment received'), findsNothing);
  });
}
