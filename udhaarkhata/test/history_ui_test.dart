import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/app.dart';
import 'package:udhaarkhata/app/router.dart';
import 'package:udhaarkhata/core/auth/account.dart';
import 'package:udhaarkhata/core/auth/auth_repository.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/core/network/app_failure.dart';
import 'package:udhaarkhata/features/ledger/history_page.dart';
import 'package:udhaarkhata/features/auth/session_controller.dart';

import 'router_test.dart' show syntheticAccount;
import 'owner_link_test.dart' show linkJson;

class HistoryAuth extends AuthRepository {
  HistoryAuth(this.role);
  final AccountRole role;
  final requests = <String>[];
  bool more = false;
  bool wrongSnapshot = false;
  AppFailure? failure;
  Completer<Object?>? delayed;
  String name = 'Synthetic Customer';
  int balance = 30000;
  final entries = <Map<String, Object?>>[
    {
      'id': 'credit',
      'serverSeq': 1,
      'shopId': 'shop',
      'linkId': 'link',
      'kind': 'credit',
      'amountPaise': 50000,
      'targetAmountPaise': null,
      'effectPaise': 50000,
      'note': 'Rice',
      'paymentMethod': null,
      'dueDate': '2026-10-15',
      'correctsEntryId': null,
      'revision': 0,
      'correctionReason': null,
      'occurredAtMs': 1790899200000,
      'createdAtMs': 1790899200000,
      'createdByUserId': 'owner',
    },
    {
      'id': 'payment',
      'serverSeq': 2,
      'shopId': 'shop',
      'linkId': 'link',
      'kind': 'payment',
      'amountPaise': 20000,
      'targetAmountPaise': null,
      'effectPaise': -20000,
      'note': null,
      'paymentMethod': 'cash',
      'dueDate': null,
      'correctsEntryId': null,
      'revision': 0,
      'correctionReason': null,
      'occurredAtMs': 1790985600000,
      'createdAtMs': 1790985600000,
      'createdByUserId': 'owner',
    },
  ];
  @override
  Future<Account?> restoreSession() async => syntheticAccount(role);
  @override
  Future<Object?> cloudRequest(
    OpaqueId accountId,
    String path, {
    Map<String, Object?>? body,
  }) async {
    requests.add(path);
    if (path.contains('/entries')) {
      if (failure != null) throw failure!;
      if (delayed != null) return delayed!.future;
    }
    final next = path.contains('cursor=');
    final page = {
      'hasMore': more && !next,
      'nextCursor': more && !next ? 'next_cursor' : null,
    };
    if (path == '/v1/me') {
      return {
        'shop': {
          'id': 'shop',
          'name': 'Store',
          'status': 'active',
          'createdAtMs': 1,
        },
        'links': [
          {
            'id': 'link',
            'shopId': 'shop',
            'shopName': 'Store',
            'balancePaise': 30000,
            'ledgerVersion': 2,
          },
        ],
        'linksHasMore': false,
      };
    }
    if (path == '/v1/shops/shop') {
      return {
        'id': 'shop',
        'name': 'Store',
        'status': 'active',
        'createdAtMs': 1,
        'totalBalancePaise': 30000,
        'customerCount': 1,
        'asOfAtMs': 1790985600000,
      };
    }
    if (path.contains('/entries')) {
      return {
        'shopId': 'shop',
        'linkId': 'link',
        'shopName': 'Store',
        'customerDisplayName': name,
        'entries': more ? [entries[next ? 1 : 0]] : entries,
        'balance': {
          'balancePaise': balance,
          'ledgerVersion': entries.length,
          'asOfServerSeq': entries.isEmpty ? 0 : 2,
          'asOfAtMs': 1790985600000,
        },
        'snapshotAtMs': wrongSnapshot && next ? 1790985600001 : 1790985600000,
        'page': page,
      };
    }
    if (path.startsWith('/v1/me/ledgers')) {
      return {
        'links': [
          {
            'id': next ? 'link2' : 'link',
            'shopId': next ? 'shop2' : 'shop',
            'shopName': next ? 'Other store' : 'Store',
            'balancePaise': 30000,
            'ledgerVersion': 2,
          },
        ],
        'snapshotAtMs': wrongSnapshot && next ? 1790985600001 : 1790985600000,
        'page': page,
      };
    }
    if (path == '/v1/shops/shop/customers/link') return linkJson;
    if (path.startsWith('/v1/shops/shop/customers')) {
      return {
        'customers': [
          next
              ? {
                  ...linkJson,
                  'id': 'link2',
                  'customerDisplayName': 'Other customer',
                }
              : linkJson,
        ],
        'hasMore': more && !next,
        'snapshotAtMs': wrongSnapshot && next ? 1790985600001 : 1790985600000,
        'page': page,
      };
    }
    throw StateError('Unexpected path');
  }
}

Future<ProviderContainer> open(WidgetTester tester, HistoryAuth auth) async {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MainApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> history(WidgetTester tester, HistoryAuth auth) async {
  final container = await open(tester, auth);
  container.read(routerProvider).go('/owner/history/shop/link');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'empty ledger is distinguished from network failure and refresh recovers',
    (tester) async {
      final auth = HistoryAuth(AccountRole.owner)..balance = 0;
      auth.entries.clear();
      await history(tester, auth);
      expect(find.text('No transactions yet.'), findsOneWidget);
      auth.failure = const AppFailure('NETWORK_ERROR', 'api.networkError');
      await tester.tap(find.text('Refresh history'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions yet.'), findsNothing);
      expect(find.textContaining('Could not connect.'), findsOneWidget);
      auth.failure = null;
      await tester.tap(find.text('Refresh history'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions yet.'), findsOneWidget);
    },
  );
  testWidgets(
    'failed next page retains dated snapshot and retries the original cursor',
    (tester) async {
      final auth = HistoryAuth(AccountRole.owner)..more = true;
      await history(tester, auth);
      auth.failure = const AppFailure('NETWORK_ERROR', 'api.networkError');
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rice'), findsOneWidget);
      expect(find.textContaining('earlier server snapshot'), findsOneWidget);
      auth.failure = null;
      await tester.ensureVisible(find.text('Retry page'));
      await tester.tap(find.text('Retry page'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cash payment received'), findsOneWidget);
      expect(
        auth.requests.where((p) => p.contains('cursor=next_cursor')).length,
        2,
      );
    },
  );
  for (final code in ['NOT_FOUND', 'FORBIDDEN', 'CURSOR_INVALID']) {
    testWidgets('history hides prior records on $code and offers refresh', (
      tester,
    ) async {
      final auth = HistoryAuth(AccountRole.owner)..more = true;
      await history(tester, auth);
      auth.failure = AppFailure(
        code,
        code == 'CURSOR_INVALID' ? 'api.cursorInvalid' : 'api.notFound',
      );
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rice'), findsNothing);
      expect(find.textContaining('₹300.00'), findsNothing);
      expect(find.text('Refresh history'), findsOneWidget);
    });
  }
  testWidgets(
    'a changed page snapshot is rejected without replacing the displayed balance',
    (tester) async {
      final auth = HistoryAuth(AccountRole.owner)
        ..more = true
        ..wrongSnapshot = true;
      await history(tester, auth);
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('records could not be verified'),
        findsOneWidget,
      );
      expect(find.textContaining('Cash payment received'), findsNothing);
    },
  );
  testWidgets(
    'account replacement ignores the previous in-flight history response',
    (tester) async {
      final old = HistoryAuth(AccountRole.owner);
      final oldResponse = await old.cloudRequest(
        OpaqueId.fromJson('old'),
        '/v1/shops/shop/customers/link/entries?limit=50',
      );
      old.delayed = Completer<Object?>();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(old)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HistoryPage(shopId: 'shop', linkId: 'link'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final replacement = HistoryAuth(AccountRole.owner)
        ..name = 'Replacement customer';
      container.updateOverrides([
        authRepositoryProvider.overrideWithValue(replacement),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Replacement customer'), findsOneWidget);
      old.delayed!.complete(oldResponse);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Customer'), findsNothing);
      expect(find.text('Replacement customer'), findsOneWidget);
    },
  );

  testWidgets(
    'owner opens dated history and pages credit/payment against the same balance',
    (tester) async {
      final auth = HistoryAuth(AccountRole.owner)..more = true;
      final container = await open(tester, auth);
      container.read(routerProvider).go('/owner/customer/shop/link');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View transaction history'));
      await tester.tap(find.text('View transaction history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Customer owes you ₹300.00'), findsOneWidget);
      expect(find.textContaining('02-10-2026'), findsWidgets);
      expect(find.textContaining('Rice'), findsOneWidget);
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cash payment received'), findsOneWidget);
      expect(
        auth.requests.any(
          (p) => p.contains('/entries?') && p.contains('cursor=next_cursor'),
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'customer taps own shop to see dated history and owed direction',
    (tester) async {
      final auth = HistoryAuth(AccountRole.customer);
      await open(tester, auth);
      await tester.tap(find.text('My shops'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Store'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You owe Store ₹300.00'), findsWidgets);
      expect(find.textContaining('Cash payment received'), findsOneWidget);
      expect(find.textContaining('Credit'), findsOneWidget);
    },
  );
  testWidgets(
    'owner sees server total and can load customers beyond first page',
    (tester) async {
      final auth = HistoryAuth(AccountRole.owner)..more = true;
      await open(tester, auth);
      expect(
        find.textContaining('Total customers owe you ₹300.00'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Other customer'), findsOneWidget);
    },
  );
}
