import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/db/database.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/shop/owner_shell.dart';
import 'package:udhaarkhata/features/shop/customer_list.dart';
import 'package:udhaarkhata/features/shop/shop_repository.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/payment_form.dart';
import 'package:udhaarkhata/features/ledger/history_page.dart';
import 'package:udhaarkhata/features/ledger/device_ledger_repository.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';

import 'auth_session_test.dart' show MemorySecureStorage;
import 'device_ledger_test.dart' show DeviceAuth;

void main() {
  sqfliteFfiInit();
  final account = OpaqueId.fromJson('owner'),
      shop = OpaqueId.fromJson('shop'),
      link = OpaqueId.fromJson('link');
  late Directory directory;
  late SqliteAccountDatabase db;
  late DeviceAuth auth;
  late DeviceLedgerRepository repo;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('udhaar_ui_d11_');
    db = SqliteAccountDatabase(
      factory: databaseFactoryFfiNoIsolate,
      directory: directory.path,
    );
    await db.openForAccount(account);
    await db.verifyAccount(account, AccountRole.owner, 1);
    auth = DeviceAuth();
    repo = DeviceLedgerRepository(auth, account, MemorySecureStorage(), db);
    await repo.prepareCustomer(shop, link);
    auth.failure = 'NETWORK_ERROR';
  });
  tearDown(() async {
    await db.lock();
    await directory.delete(recursive: true);
  });
  Future<void> settleIo(WidgetTester tester, {Finder? expected}) async {
    await tester.pump();
    for (var attempt = 0; attempt < 500; attempt++) {
      final busy =
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('Checking credit…').evaluate().isNotEmpty ||
          find.text('Checking payment…').evaluate().isNotEmpty;
      if (!busy && (expected == null || expected.evaluate().isNotEmpty)) break;
      // Native SQLite/file work can complete outside Flutter's simulated clock.
      // Wait for the actual screen outcome rather than a fixed success delay.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(repo),
          ownerLinkRepositoryProvider.overrideWithValue(null),
          currentShopProvider.overrideWith(
            (ref) async => throw const AppFailure(
              "NETWORK_ERROR",
              "api.networkError",
              retryable: true,
            ),
          ),
        ],
        child: MaterialApp(home: page),
      ),
    );
    // Real SQLite runs without an extra isolate so widget fake time can settle.
    await settleIo(tester);
  }

  testWidgets('offline credit review is inert; confirm saves Pending once', (
    tester,
  ) async {
    await open(tester, CreditPage(shopId: shop, linkId: link));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (₹)'),
      '200',
    );
    await tester.tap(find.text('Review credit'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(repo.outbox), isEmpty);
    await tester.tap(find.text('Confirm credit'));
    await tester.tap(find.text('Confirm credit'), warnIfMissed: false);
    await settleIo(tester, expected: find.textContaining('₹700.00'));
    expect(find.text('Credit saved · Pending'), findsOneWidget);
    expect(find.textContaining('only on this device'), findsWidgets);
    expect(find.text('Credit acknowledged by server'), findsNothing);
    expect(await tester.runAsync(repo.outbox), hasLength(1));
    expect(auth.bodies, isEmpty);
  });
  testWidgets('offline payment enforces local balance then saves manual Cash', (
    tester,
  ) async {
    await open(tester, PaymentPage(shopId: shop, linkId: link));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount received (₹)'),
      '501',
    );
    await tester.tap(find.text('Review payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm payment received'));
    await settleIo(
      tester,
      expected: find.textContaining('locally known balance'),
    );
    expect(await tester.runAsync(repo.outbox), isEmpty);
    expect(find.textContaining('locally known balance'), findsOneWidget);
    await tester.tap(find.text('Edit payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount received (₹)'),
      '200',
    );
    await tester.tap(find.text('Review payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm payment received'));
    await settleIo(tester, expected: find.textContaining('₹300.00'));
    expect(find.text('Payment saved · Pending'), findsOneWidget);
    expect(find.text('Payment acknowledged by server'), findsNothing);
    expect(
      (await tester.runAsync(() => repo.snapshot(shop, link)))!
          .provisionalPaise,
      30000,
    );
    expect(auth.bodies, isEmpty);
  });
  testWidgets(
    'saved customers remain reachable when the shop read is offline',
    (tester) async {
      await open(tester, const OwnerShell());
      expect(find.text('Saved customer ledgers'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('explicit server denial hides cached history and keeps Pending', (
    tester,
  ) async {
    await tester.runAsync(
      () => repo.begin(shop, link, 'Customer', 1, null, null),
    );
    await open(tester, const HistoryPage(shopId: 'shop', linkId: 'link'));
    auth.failure = 'FORBIDDEN';
    await tester.tap(find.text('Refresh from server'));
    await settleIo(tester);
    expect(find.text('Credit ₹500.00'), findsNothing);
    expect(
      find.textContaining('(provisional, including Pending)'),
      findsNothing,
    );
    expect(await tester.runAsync(repo.outbox), hasLength(1));
  });
  testWidgets('oversized customer ledger exposes confirmed server history', (
    tester,
  ) async {
    await db.transaction(account, (tx) => tx.delete('owner_ledger_snapshots'));
    auth.failure = null;
    auth.tooLarge = true;
    await open(tester, OwnerCustomerPage(shopId: shop, linkId: link));
    expect(find.text('View confirmed server history'), findsOneWidget);
  });
  testWidgets(
    'legacy credit recovery does not require a complete offline cache',
    (tester) async {
      final legacy = CloudLedgerRepository(auth, account, repo.storage);
      final saved = await legacy.begin(shop, link, 'Customer', 100, null, null);
      await db.transaction(
        account,
        (tx) => tx.delete('owner_ledger_snapshots'),
      );
      auth.failure = null;
      auth.tooLarge = true;
      await open(tester, CreditPage(shopId: shop, linkId: link));
      expect(find.text('Check same credit'), findsOneWidget);
      expect((await repo.pending(shop, link))!.operationId, saved.operationId);
      expect(auth.bodies, isEmpty);
    },
  );
  testWidgets(
    'legacy payment recovery does not require a complete offline cache',
    (tester) async {
      final legacy = CloudLedgerRepository(auth, account, repo.storage);
      final saved = await legacy.beginPayment(
        shop,
        link,
        'Customer',
        100,
        'cash',
      );
      await db.transaction(
        account,
        (tx) => tx.delete('owner_ledger_snapshots'),
      );
      auth.failure = null;
      auth.tooLarge = true;
      await open(tester, PaymentPage(shopId: shop, linkId: link));
      expect(find.text('Check same payment'), findsOneWidget);
      expect(
        (await repo.pendingPayment(shop, link))!.attempt.operationId,
        saved.operationId,
      );
      expect(auth.bodies, isEmpty);
    },
  );
  testWidgets(
    'reopened owner history labels each status and provisional balance',
    (tester) async {
      await tester.runAsync(() async {
        await repo.begin(shop, link, 'Customer', 20000, 'Salt', null);
        await repo.beginPayment(shop, link, 'Customer', 10000, 'upi');
      });
      await open(tester, const HistoryPage(shopId: 'shop', linkId: 'link'));
      expect(find.textContaining('₹600.00'), findsOneWidget);
      expect(find.textContaining('Synced'), findsWidgets);
      expect(find.textContaining('Pending'), findsWidgets);
      await tester.ensureVisible(find.text('Details').at(1));
      await tester.tap(find.text('Details').at(1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Salt'), findsOneWidget);
      expect(find.text('UPI payment received'), findsOneWidget);
      expect(find.textContaining('only on this device'), findsWidgets);
    },
  );
}
